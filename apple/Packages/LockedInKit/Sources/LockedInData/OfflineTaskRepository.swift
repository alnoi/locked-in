import Foundation
import LockedInDomain

public actor OfflineTaskRepository: TrackerRepository, TaskOrderRepository {
  private struct Pending: Codable {
    var version = UUID()
    var task: TaskRecord
    var base: TaskRecord?
    var isNew: Bool
    var deleted = false
    var restoring: Bool?
    var inheritedTagsDisabled: Bool?
    var restoredComments: [CommentRecord]?
  }
  private struct PendingTaskOrder: Codable {
    var version = UUID()
    var taskIDs: [UUID]
    var initializeOnly: Bool
  }
  private struct Archive: Codable {
    var snapshot: Snapshot
    var pending: [Pending] = []
    var pendingTaskOrder: PendingTaskOrder?
  }
  private let remote: any TaskSyncRemote
  private let file: URL
  private let seedFile: URL?
  private let orderSpace: String?
  private var archive: Archive?
  private var serverTasks: [UUID: TaskRecord] = [:]
  private var syncing = false
  private var offline = true
  private var issue: String?
  public init(remote: any TaskSyncRemote, file: URL, seedFile: URL? = nil, orderSpace: String? = nil) {
    self.remote = remote; self.file = file; self.seedFile = seedFile; self.orderSpace = orderSpace
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
    TaskSyncStatus(pendingTaskIDs: Set(archive?.pending.map { $0.task.id } ?? []), hasPendingTaskOrder: archive?.pendingTaskOrder != nil, isOffline: offline, issue: issue)
  }
  public func load() async throws -> Snapshot {
    _ = try restore()
    if syncing, let archive { return archive.snapshot }
    syncing = true
    defer { syncing = false }
    do {
      let remoteSnapshot = try await remote.load()
      var next = archive ?? Archive(snapshot: remoteSnapshot)
      guard (next.pending.isEmpty && next.pendingTaskOrder == nil) || next.snapshot.user.id == remoteSnapshot.user.id else {
        throw TrackerError.conflict("На сервере другой пользователь. Несинхронизированные задачи сохранены на устройстве.")
      }
      serverTasks = Dictionary(uniqueKeysWithValues: remoteSnapshot.tasks.map { ($0.id, $0) })
      next.snapshot = remoteSnapshot
      seedTaskOrder(&next)
      overlayPending(&next)
      try save(next)
      offline = false
      issue = nil
      let ids = next.pending.map { $0.task.id }
      for id in ids {
        guard let pending = archive?.pending.first(where: { $0.task.id == id }) else { continue }
        do { try await send(pending) }
        catch {
          if (error as? AuthenticationError) == .sessionExpired { throw error }
          if SyncConnectionError.isRetryable(error) {
            offline = UserFacingErrors.isConnectionFailure(error)
            issue = offline ? nil : UserFacingErrors.message(error)
            break
          }
          issue = UserFacingErrors.message(error)
        }
      }
      if archive?.pending.isEmpty == true, let order = archive?.pendingTaskOrder {
        do { try await sendTaskOrder(order) }
        catch {
          if (error as? AuthenticationError) == .sessionExpired { throw error }
          offline = UserFacingErrors.isConnectionFailure(error)
          issue = offline ? nil : UserFacingErrors.message(error)
        }
      }
      return archive!.snapshot
    } catch {
      if SyncConnectionError.isRetryable(error), let archive {
        offline = UserFacingErrors.isConnectionFailure(error)
        issue = offline ? nil : UserFacingErrors.message(error)
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
    var restoring = false
    var inheritedTagsDisabled = false
    switch change {
    case .restore(.task(let restored)):
      try TrackerRules.validate(TaskInput(restored), id: restored.id, in: snapshot)
      task = restored
      restoring = true
      result = .task(restored)

    case .task(let id, let input):
      inheritedTagsDisabled = input.inheritProjectTags == false
      let input = TrackerRules.inheritingProjectTags(input, id: id, in: snapshot)
      try TrackerRules.validate(input, id: id, in: snapshot)
      let existing = snapshot.tasks.first { $0.id == id }
      if id != nil && existing == nil { throw TrackerError.notFound }
      task = TaskRecord(id: id ?? UUID(), input: input, completed: existing?.completed ?? false,
        createdAt: existing?.createdAt ?? .now)
      isNew = id == nil
      result = .task(task)
    case .restore(.comment(let comment)):
      if let index = next.pending.firstIndex(where: { $0.task.id == comment.taskID && $0.restoring == true }) {
        var comments = next.pending[index].restoredComments ?? []
        comments.removeAll { $0.id == comment.id }
        comments.append(comment)
        next.pending[index].restoredComments = comments
        next.snapshot.receive(.comment(comment))
        try save(next)
        return .comment(comment)
      }
      guard !offline else { throw SyncConnectionError.connectionRequired }
      let response = try await remote.apply(change)
      next.snapshot.receive(response)
      try save(next)
      return response
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
        if UserFacingErrors.isConnectionFailure(error) {
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
      if restoring { next.pending[index].restoring = true }
      next.pending[index].inheritedTagsDisabled = inheritedTagsDisabled
    } else {
      next.pending.append(Pending(task: task, base: snapshot.tasks.first { $0.id == task.id }, isNew: isNew, deleted: deleted, restoring: restoring, inheritedTagsDisabled: inheritedTagsDisabled))
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
      if pending.restoring == true && !pending.isNew {
        do { _ = try await remote.apply(.restore(.task(pending.task))) }
        catch {
          guard let tracker = error as? TrackerError, case .notFound = tracker else { throw error }
          _ = try await remote.createTask(id: pending.task.id, input: TaskInput(pending.task))
        }
      }
      if pending.isNew { _ = try await remote.createTask(id: pending.task.id, input: TaskInput(pending.task)) }
      let serverTask = serverTasks[pending.task.id]
      let desired = TaskSyncMerge.merging(local: pending.task, base: pending.base, remote: serverTask)
      var input = TaskInput(desired)
      if pending.inheritedTagsDisabled == true { input.inheritProjectTags = false }
      guard case .task(var saved) = try await remote.apply(.task(pending.task.id, input)) else {
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
  public func saveTaskOrder(_ ids: [UUID], initializeOnly: Bool) async throws -> TaskOrder {
    guard let snapshot = try restore() else {
      throw TrackerError.validation("Сначала подключись к серверу, чтобы загрузить задачи.")
    }
    let available = Set(snapshot.tasks.map(\.id))
    guard Set(ids).count == ids.count, Set(ids).isSubset(of: available) else {
      throw TrackerError.validation("Не удалось сохранить порядок. Обнови список задач.")
    }
    var next = archive!
    if initializeOnly, let order = snapshot.taskOrder, order.revision > 0 { return order }
    let current = TaskOrdering.orderedIDs(snapshot.tasks, stored: snapshot.taskOrder?.taskIDs ?? [])
    let result = TaskOrder(taskIDs: TaskOrdering.merging(ids, into: current), revision: snapshot.taskOrder?.revision ?? 0)
    let selected = Set(next.pendingTaskOrder?.taskIDs ?? []).union(ids)
    let pendingIDs = result.taskIDs.filter { selected.contains($0) }
    let initial = initializeOnly && (next.pendingTaskOrder?.initializeOnly ?? true)
    next.pendingTaskOrder = PendingTaskOrder(taskIDs: pendingIDs, initializeOnly: initial)
    next.snapshot.taskOrder = result
    try save(next)
    return result
  }
  private func seedTaskOrder(_ value: inout Archive) {
    guard value.pendingTaskOrder == nil, value.snapshot.taskOrder?.revision == 0,
      let orderSpace, TaskOrderPreferences.hasSavedOrder(space: orderSpace, userID: value.snapshot.user.id) else { return }
    let ids = TaskOrderPreferences.orderedIDs(value.snapshot.tasks, space: orderSpace, userID: value.snapshot.user.id)
    value.pendingTaskOrder = PendingTaskOrder(taskIDs: ids, initializeOnly: true)
  }
  private func sendTaskOrder(_ pending: PendingTaskOrder) async throws {
    guard let remote = remote as? any TaskOrderRepository, let snapshot = archive?.snapshot else {
      throw RequestFailure.unsupportedAction
    }
    let available = Set(snapshot.tasks.map(\.id))
    let ids = pending.taskIDs.filter { available.contains($0) }
    let result = try await remote.saveTaskOrder(ids, initializeOnly: pending.initializeOnly)
    var next = archive!
    if next.pendingTaskOrder?.version == pending.version { next.pendingTaskOrder = nil }
    next.snapshot.taskOrder = result
    overlayPending(&next)
    try save(next)
  }
  private func overlayPending(_ value: inout Archive) {
    for pending in value.pending {
      value.snapshot.receive(pending.deleted ? .deleted(.task, pending.task.id) : .task(pending.task))
      if !pending.deleted {
        for comment in pending.restoredComments ?? [] { value.snapshot.receive(.comment(comment)) }
      }
    }
    if let order = value.snapshot.taskOrder {
      let current = TaskOrdering.orderedIDs(value.snapshot.tasks, stored: order.taskIDs)
      let available = Set(current)
      let selected = value.pendingTaskOrder?.taskIDs.filter { available.contains($0) } ?? []
      value.snapshot.taskOrder = TaskOrder(taskIDs: TaskOrdering.merging(selected, into: current), revision: order.revision)
    }
  }
  private func save(_ value: Archive) throws {
    try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONCodec.encoder().encode(value).write(to: file, options: .atomic)
    archive = value
  }
}
