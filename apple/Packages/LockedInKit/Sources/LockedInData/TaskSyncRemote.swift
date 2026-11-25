import Foundation
import LockedInDomain

public protocol TaskSyncRemote: TrackerRepository {
  func createTask(id: UUID, input: TaskInput) async throws -> TaskRecord
}
public enum SyncConnectionError: Error, LocalizedError {
  case serverUnavailable
  case connectionRequired
  case internalFailure
  public var errorDescription: String? {
    switch self {
    case .serverUnavailable: RequestFailure.noConnection.localizedDescription
    case .connectionRequired: "Для этого действия нужна связь с сервером. Подключись и попробуй ещё раз."
    case .internalFailure: RequestFailure.internalError.localizedDescription
    }
  }
  public static func isRetryable(_ error: Error) -> Bool {
    if error is SyncConnectionError { return true }
    return UserFacingErrors.isConnectionFailure(error)
  }
}
public struct TaskSyncStatus: Sendable {
  public var pendingTaskIDs: Set<UUID>
  public var hasPendingTaskOrder = false
  public var isOffline: Bool
  public var issue: String?
}
