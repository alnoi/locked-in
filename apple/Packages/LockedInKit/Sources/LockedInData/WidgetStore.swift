import Foundation
import CoreFoundation
import LockedInDomain

public struct WidgetSnapshot: Codable, Sendable {
  public var source: String
  public var userID: UUID
  public var mode: StorageMode
  public var serverAddress: String
  public var tasks: [TaskRecord]
  public var tags: [TagRecord]
  public var pendingTaskIDs: Set<UUID>
  public var theme: String
  public var updatedAt: Date
  public var sourceKey: String { source + ":" + userID.uuidString }
  public init(snapshot: Snapshot, settings: ConnectionSettings, pendingTaskIDs: Set<UUID> = [],
    theme: String = "system", updatedAt: Date = .now) {
    source = settings.identity; userID = snapshot.user.id; mode = settings.mode
    serverAddress = settings.serverAddress; tasks = snapshot.tasks; tags = snapshot.tags
    self.pendingTaskIDs = pendingTaskIDs; self.theme = theme; self.updatedAt = updatedAt
  }
}

public struct WidgetCompletion: Codable, Identifiable, Sendable {
  public var id = UUID()
  public var sourceKey: String
  public var taskID: UUID
  public var createdAt = Date.now
  public var acknowledgedTask: TaskRecord?
  public init(sourceKey: String, taskID: UUID) { self.sourceKey = sourceKey; self.taskID = taskID }
}

// Each process owns its snapshot file. Completion commands are individual atomic
// files, so a widget can never overwrite the app's repository or offline queue.
public struct WidgetStore: Sendable {
  public static var groupID: String {
    #if os(macOS)
    Bundle.main.object(forInfoDictionaryKey: "TrackItAppGroup") as? String ?? ""
    #else
    "group.com.alan.planner"
    #endif
  }
  private let directory: URL
  public init(directory: URL) { self.directory = directory }
  public static var shared: WidgetStore? {
    guard !groupID.isEmpty, !groupID.hasPrefix("."), !groupID.contains("$(") else { return nil }
    return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
      .map { WidgetStore(directory: $0.appendingPathComponent("TrackItWidgets", isDirectory: true)) }
  }
  @discardableResult public func publish(_ snapshot: WidgetSnapshot) throws -> Bool {
    if let previous = try context(), previous.sourceKey == snapshot.sourceKey,
      previous.pendingTaskIDs == snapshot.pendingTaskIDs {
      // Compare persisted precision, not subsecond Dates lost by ISO8601 encoding.
      var old = previous; old.pendingTaskIDs = []
      var next = snapshot; next.pendingTaskIDs = []; next.updatedAt = old.updatedAt
      if try JSONCodec.encoder().encode(old) == JSONCodec.encoder().encode(next) { return false }
    }
    try write(snapshot, to: directory.appendingPathComponent("app.json"))
    return true
  }
  public func clearContext() throws {
    let url = directory.appendingPathComponent("app.json")
    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
  }
  public func context() throws -> WidgetSnapshot? {
    try read(WidgetSnapshot.self, from: directory.appendingPathComponent("app.json"))
  }
  public func displaySnapshot() throws -> WidgetSnapshot? {
    guard var value = try context() else { return nil }
    if value.mode == .server, let remote = try read(WidgetSnapshot.self, from: remoteURL(value)),
      remote.updatedAt > value.updatedAt {
      let pending = value.tasks.filter { value.pendingTaskIDs.contains($0.id) }
      remote.tasks.forEach { task in
        if !value.pendingTaskIDs.contains(task.id) {
          value.tasks.removeAll { $0.id == task.id }; value.tasks.append(task)
        }
      }
      let remoteIDs = Set(remote.tasks.map(\.id))
      value.tasks.removeAll { !remoteIDs.contains($0.id) && !value.pendingTaskIDs.contains($0.id) }
      for task in pending where !value.tasks.contains(where: { $0.id == task.id }) { value.tasks.append(task) }
      value.tags = remote.tags; value.updatedAt = remote.updatedAt
    }
    for command in try commands(sourceKey: value.sourceKey) {
      guard let index = value.tasks.firstIndex(where: { $0.id == command.taskID }) else { continue }
      if let ack = command.acknowledgedTask, value.tasks[index].updatedAt > ack.updatedAt { continue }
      value.tasks[index].completed = true
    }
    return value
  }
  public func saveRemote(_ snapshot: WidgetSnapshot) throws {
    guard try context()?.sourceKey == snapshot.sourceKey else { return }
    try write(snapshot, to: remoteURL(snapshot))
  }
  @discardableResult public func enqueueCompletion(taskID: UUID, sourceKey: String) throws -> WidgetCompletion {
    guard let value = try context(), value.sourceKey == sourceKey,
      value.tasks.contains(where: { $0.id == taskID }) else { throw TrackerError.notFound }
    if let existing = try commands(sourceKey: sourceKey).first(where: { $0.taskID == taskID && $0.acknowledgedTask == nil }) {
      return existing
    }
    let command = WidgetCompletion(sourceKey: sourceKey, taskID: taskID)
    try update(command)
    return command
  }
  public static let changeNotification = "com.alan.planner.widgetCommandsChanged"
  public func update(_ command: WidgetCompletion) throws {
    try write(command, to: commandURL(command.id))
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
      CFNotificationName(Self.changeNotification as CFString), nil, nil, true)
  }
  public func commands(sourceKey: String) throws -> [WidgetCompletion] {
    let folder = directory.appendingPathComponent("commands", isDirectory: true)
    guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
    return try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "json" }
      .compactMap { url -> WidgetCompletion? in
        do { return try JSONCodec.decoder().decode(WidgetCompletion.self, from: Data(contentsOf: url)) }
        catch CocoaError.fileReadNoSuchFile { return nil }
      }
      .filter { $0.sourceKey == sourceKey }.sorted { $0.createdAt < $1.createdAt }
  }
  public func remove(_ command: WidgetCompletion) throws {
    let url = commandURL(command.id)
    if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
  }
  private func commandURL(_ id: UUID) -> URL {
    directory.appendingPathComponent("commands", isDirectory: true).appendingPathComponent(id.uuidString + ".json")
  }
  private func remoteURL(_ value: WidgetSnapshot) -> URL {
    let key = Data(value.sourceKey.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
    return directory.appendingPathComponent("remote_" + key + ".json")
  }
  private func read<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    return try JSONCodec.decoder().decode(type, from: Data(contentsOf: url))
  }
  private func write<T: Encodable>(_ value: T, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONCodec.encoder().encode(value).write(to: url, options: .atomic)
  }
}
