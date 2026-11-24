import Foundation
import LockedInDomain
import OSLog
import UserNotifications

public enum UserFacingErrors {
  public static func message(_ error: Error) -> String {
    if let known = error as? RequestFailure { return known.localizedDescription }
    if let known = error as? AuthenticationError { return known.localizedDescription }
    if let known = error as? TrackerError { return known.localizedDescription }
    if let known = error as? SyncConnectionError { return known.localizedDescription }
    let failure = error as NSError
    if failure.domain == UNErrorDomain {
      return "Уведомления недоступны. Разреши их для TrackIt в системных настройках."
    }
    if failure.domain == NSOSStatusErrorDomain { return RequestFailure.secureStorage.localizedDescription }
    if isConnectionFailure(error) { return RequestFailure.noConnection.localizedDescription }
    if error is CancellationError || (error as? URLError)?.code == .cancelled {
      return RequestFailure.cancelled.localizedDescription
    }
    if let error = error as? URLError, [.badURL, .unsupportedURL].contains(error.code) {
      return "Проверь адрес сервера в настройках подключения."
    }
    Logger(subsystem: "com.alan.planner", category: "errors")
      .error("Unexpected client error: \(error.localizedDescription, privacy: .private)")
    return RequestFailure.internalError.localizedDescription
  }
  public static func isConnectionFailure(_ error: Error) -> Bool {
    if let error = error as? SyncConnectionError {
      switch error {
      case .serverUnavailable, .connectionRequired: return true
      case .internalFailure: return false
      }
    }
    if case RequestFailure.noConnection = error { return true }
    guard let error = error as? URLError else { return false }
    return [.cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .timedOut,
      .networkConnectionLost, .dnsLookupFailed, .dataNotAllowed, .internationalRoamingOff,
      .secureConnectionFailed, .serverCertificateHasBadDate, .serverCertificateUntrusted,
      .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid].contains(error.code)
  }
}
