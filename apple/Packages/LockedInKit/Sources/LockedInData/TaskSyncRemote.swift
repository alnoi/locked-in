import Foundation
import LockedInDomain

public protocol TaskSyncRemote: TrackerRepository {
  func createTask(id: UUID, input: TaskInput) async throws -> TaskRecord
}
public enum SyncConnectionError: Error, LocalizedError {
  case serverUnavailable
  case connectionRequired
  public var errorDescription: String? {
    switch self {
    case .serverUnavailable: "Сервер временно недоступен. Изменения сохранены на устройстве."
    case .connectionRequired: "Для этого действия нужна связь с сервером. Подключись и попробуй ещё раз."
    }
  }
  public static func isRetryable(_ error: Error) -> Bool {
    if error is SyncConnectionError { return true }
    guard let error = error as? URLError else { return false }
    return [.cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .timedOut,
      .networkConnectionLost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff].contains(error.code)
  }
}
public struct TaskSyncStatus: Sendable {
  public var pendingTaskIDs: Set<UUID>
  public var isOffline: Bool
  public var issue: String?
}
