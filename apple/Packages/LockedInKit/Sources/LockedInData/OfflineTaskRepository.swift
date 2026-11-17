import Foundation
import LockedInDomain

public actor OfflineTaskRepository: TrackerRepository {
  private struct Pending: Codable {
    var version = UUID()
    var task: TaskRecord
    var base: TaskRecord?
    var isNew: Bool
    var deleted = false
  }
  private struct Archive: Codable {
    var snapshot: Snapshot
    var pending: [Pending] = []
  }
  private let remote: any TaskSyncRemote
  private let file: URL
  private let seedFile: URL?
  private var archive: Archive?
  private var serverTasks: [UUID: TaskRecord] = [:]
  private var syncing = false
  private var offline = true
  private var issue: String?
  public init(remote: any TaskSyncRemote, file: URL, seedFile: URL? = nil) {
    self.remote = remote; self.file = file; self.seedFile = seedFile
  }
  public func restore() throws -> Snapshot? {
    if archive == nil {
      if FileManager.default.fileExists(atPath: file.path) {
        archive = try JSONCodec.decoder().decode(Archive.self, from: Data(contentsOf: file))
      } else if let seedFile, FileManager.default.fileExists(atPath: seedFile.path) {
        archive = Archive(snapshot: try JSONCodec.decoder().decode(Snapshot.self, from: Data(contentsOf: seedFile)))
      }
    }
    return archive?.snapshot
  }
  public func status() -> TaskSyncStatus {
    TaskSyncStatus(pendingTaskIDs: Set(archive?.pending.map { $0.task.id } ?? []), isOffline: offline, issue: issue)
  }
  public func load() async throws -> Snapshot {
    _ = try restore()
    if syncing, let archive { return archive.snapshot }
    syncing = true
    defer { syncing = false }
    do {
      let remoteSnapshot = try await remote.load()
      var next = archive ?? Archive(snapshot: remoteSnapshot)
      guard next.pending.isEmpty || next.snapshot.user.id == remoteSnapshot.user.id else {
        throw TrackerError.conflict("На сервере другой пользователь. Несинхронизированные задачи сохранены на устройстве.")
      }
      serverTasks = Dictionary(uniqueKeysWithValues: remoteSnapshot.tasks.map { ($0.id, $0) })
      next.snapshot = remoteSnapshot
      overlayPending(&next)
      try save(next)
      offline = false
      issue = nil
      let ids = next.pending.map { $0.task.id }
      for id in ids {
        guard let pending = archive?.pending.first(where: { $0.task.id == id }) else { continue }
        do { try await send(pending) }
        catch {
          if SyncConnectionError.isRetryable(error) { offline = true; break }
          issue = error.localizedDescription
        }
      }
      return archive!.snapshot
    } catch {
      if SyncConnectionError.isRetryable(error), let archive {
        offline = true
        return archive.snapshot
      }
      throw error
    }
  }
  public func apply(_ change: Change) async throws -> ChangeResult {
    guard let snapshot = try restore() else {
      throw TrackerError.validation("Сначала подключись к серверу, чтобы загрузить данные пользователя.")
    }
    var next = archive!
    let result: ChangeResult
    let task: TaskRecord
    var isNew = false
    var deleted = false
    switch change {
    case .task(let id, let input):
      try TrackerRules.validate(input, id: id, in: snapshot)
      let existing = snapshot.tasks.first { $0.id == id }
      if id != nil && existing == nil { throw TrackerError.notFound }
      task = TaskRecord(id: id ?? UUID(), input: input, completed: existing?.completed ?? false,
        createdAt: existing?.createdAt ?? .now)
      isNew = id == nil
      result = .task(task)
    case .completed(let id, let completed):
      guard var current = snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
      current.completed = completed; current.updatedAt = .now
      task = current
      result = .task(current)
    case .deleteTask(let id):
      guard let current = snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
      guard !snapshot.tasks.contains(where: { $0.parentID == id }) else {
        throw TrackerError.conflict("Сначала перенеси или удали дочерние задачи.")
      }
      task = current; deleted = true
      result = .deleted(.task, id)
    default:
      guard !offline else { throw SyncConnectionError.connectionRequired }
      let response: ChangeResult
      do { response = try await remote.apply(change) }
      catch {
        if SyncConnectionError.isRetryable(error) {
          offline = true
          throw SyncConnectionError.connectionRequired
        }
        throw error
      }
      var latest = archive!
      latest.snapshot.receive(response)
      if case .deleteList(let id) = change {
        for index in latest.pending.indices where latest.pending[index].task.listID == id {
          latest.pending[index].task.listID = nil
          if latest.pending[index].base?.listID == id { latest.pending[index].base?.listID = nil }
          latest.pending[index].version = UUID()
        }
        for taskID in Array(serverTasks.keys) where serverTasks[taskID]?.listID == id {
          serverTasks[taskID]?.listID = nil
        }
      }
      overlayPending(&latest)
      try save(latest)
      return response
    }
    if let index = next.pending.firstIndex(where: { $0.task.id == task.id }) {
      next.pending[index].version = UUID()
      next.pending[index].task = task
      next.pending[index].deleted = deleted
    } else {
      next.pending.append(Pending(task: task, base: snapshot.tasks.first { $0.id == task.id }, isNew: isNew, deleted: deleted))
    }
    next.snapshot.receive(result)
    try save(next)
    return result
  }
  private func send(_ pending: Pending) async throws {
    let result: ChangeResult
    if pending.deleted {
      do { _ = try await remote.apply(.deleteTask(pending.task.id)) }
      catch {
        guard let tracker = error as? TrackerError, case .notFound = tracker else { throw error }
      }
      result = .deleted(.task, pending.task.id)
    } else {
      if pending.isNew { _ = try await remote.createTask(id: pending.task.id, input: TaskInput(pending.task)) }
      let serverTask = serverTasks[pending.task.id]
      let desired = TaskSyncMerge.merging(local: pending.task, base: pending.base, remote: serverTask)
      guard case .task(var saved) = try await remote.apply(.task(pending.task.id, TaskInput(desired))) else {
        throw TrackerError.validation("Сервер вернул неожиданный ответ при сохранении задачи.")
      }
      if saved.completed != desired.completed {
        guard case .task(let completed) = try await remote.apply(.completed(saved.id, desired.completed)) else {
          throw TrackerError.validation("Сервер не подтвердил статус задачи.")
        }
        saved = completed
      }
      result = .task(saved)
    }
    if case .task(let task) = result { serverTasks[task.id] = task }
    var next = archive!
    if let index = next.pending.firstIndex(where: { $0.task.id == pending.task.id }) {
      if next.pending[index].version == pending.version { next.pending.remove(at: index) }
      else { next.pending[index].isNew = false }
    }
    next.snapshot.receive(result)
    overlayPending(&next)
    try save(next)
  }
  private func overlayPending(_ value: inout Archive) {
    for pending in value.pending {
      value.snapshot.receive(pending.deleted ? .deleted(.task, pending.task.id) : .task(pending.task))
    }
  }
  private func save(_ value: Archive) throws {
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONCodec.encoder().encode(value).write(to: file, options: .atomic)
    archive = value
  }
}
