import Foundation
import LockedInDomain

public enum WidgetService {
  public static func refresh(store: WidgetStore, client: (any TaskSyncRemote)? = nil) async throws -> WidgetSnapshot? {
    guard let value = try store.context(), value.mode == .server else { return try store.displaySnapshot() }
    let requestedAt = Date.now
    do {
      let repository = try client ?? remote(value)
      let snapshot = try await repository.load()
      guard snapshot.user.id == value.userID,
        let current = try store.context(), current.sourceKey == value.sourceKey,
        sameContext(current, value)
      else { return try store.displaySnapshot() }
      var updated = WidgetSnapshot(snapshot: snapshot,
        settings: ConnectionSettings(mode: value.mode, serverAddress: value.serverAddress, accountID: value.userID),
        theme: value.theme, updatedAt: requestedAt)
      updated.pendingTaskIDs = value.pendingTaskIDs
      try store.saveRemote(updated)
    } catch {
      // Keep the last good snapshot and queued actions while disconnected.
    }
    return try store.displaySnapshot()
  }
  public static func complete(taskID: UUID, sourceKey: String, store: WidgetStore, client: (any TaskSyncRemote)? = nil) async throws {
    var command = try store.enqueueCompletion(taskID: taskID, sourceKey: sourceKey)
    guard let value = try store.context(), value.mode == .server else { return }
    do {
      let remote = try client ?? remote(value)
      let snapshot = try await remote.load()
      guard snapshot.user.id == value.userID else { return }
      if case .task(let task) = try await remote.apply(.completed(taskID, true)) {
        command.acknowledgedTask = task
        try store.update(command)
      }
    } catch {
      // The durable command is imported by the app's normal offline queue.
    }
  }
  private static func sameContext(_ lhs: WidgetSnapshot, _ rhs: WidgetSnapshot) -> Bool {
    guard lhs.pendingTaskIDs == rhs.pendingTaskIDs else { return false }
    var left = lhs; left.pendingTaskIDs = []
    var right = rhs; right.pendingTaskIDs = []
    return (try? JSONCodec.encoder().encode(left)) == (try? JSONCodec.encoder().encode(right))
  }
  static func remote(_ value: WidgetSnapshot) throws -> HTTPRepository {
    let url = try ConnectionSettings(mode: .server, serverAddress: value.serverAddress).validatedURL()
    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 5
    configuration.timeoutIntervalForResource = 8
    guard let session = try AuthSessionStore.load(address: value.serverAddress, userID: value.userID),
      session.expiresAt > .now else { throw AuthenticationError.sessionExpired }
    return HTTPRepository(baseURL: url, session: URLSession(configuration: configuration), accessToken: session.accessToken)
  }
}
