import Foundation
import LockedInDomain

public struct WidgetTaskCreation: Codable, Identifiable, Sendable {
  public var id: UUID { task.id }
  public var sourceKey: String
  public var task: TaskRecord
  public var acknowledged: Bool = false
  public init(sourceKey: String, title: String) {
    self.sourceKey = sourceKey
    task = TaskRecord(input: TaskInput(title: title))
  }
}

public enum WidgetQuickTask {
  public static func create(title: String, sourceKey: String, store: WidgetStore) async throws -> Bool {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    try TrackerRules.name(title)
    guard let context = try store.context(), context.sourceKey == sourceKey else {
      throw TrackerError.validation("Аккаунт изменился. Запусти команду ещё раз.")
    }
    if context.mode == .server {
      guard let session = try AuthSessionStore.load(address: context.serverAddress, userID: context.userID),
        session.expiresAt > .now else { throw AuthenticationError.sessionExpired }
    }
    let command = WidgetTaskCreation(sourceKey: sourceKey, title: title)
    try store.saveCreation(command)
    if context.mode == .server {
      do {
        let remote = try WidgetService.remote(context)
        _ = try await remote.createTask(id: command.id, input: TaskInput(command.task))
        var acknowledged = command
        acknowledged.acknowledged = true
        try store.saveCreation(acknowledged)
        return true
      } catch {
        return false
      }
    }
    return false
  }
}
