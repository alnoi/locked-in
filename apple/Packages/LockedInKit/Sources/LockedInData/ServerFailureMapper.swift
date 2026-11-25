import Foundation
import LockedInDomain

enum ServerFailureMapper {
  enum Operation { case login, registration, profile, tracker, ping, report }
  private struct Payload: Decodable { var code: String }
  private static let statuses: [String: Int] = [
    "invalid_attachment": 400, "validation_error": 400, "invalid_username": 400, "invalid_password": 400,
    "invalid_avatar": 400, "invalid_time_zone": 400, "invalid_credentials": 401,
    "user_not_found": 401, "wrong_password": 401, "unauthorized": 401, "forbidden": 403, "not_found": 404, "method_not_allowed": 405,
    "conflict": 409, "username_taken": 409, "rate_limited": 429,
    "internal_error": 500, "server_unavailable": 503,
  ]
  static func error(status: Int, data: Data, operation: Operation) -> Error {
    let code = (try? JSONDecoder().decode(Payload.self, from: data))?.code
    if let code, statuses[code] != status { return SyncConnectionError.internalFailure }
    switch code {
    case "invalid_attachment": return RequestFailure.invalidAttachment
    case "invalid_username": return RequestFailure.invalidUsername
    case "invalid_password": return RequestFailure.invalidPassword
    case "invalid_avatar": return RequestFailure.invalidAvatar
    case "invalid_time_zone": return RequestFailure.invalidTimeZone
    default: break
    }
    switch status {
    case 400: return operation == .registration ? AuthenticationError.invalidRegistration : RequestFailure.invalidRequest
    case 401:
      guard operation == .login else { return AuthenticationError.sessionExpired }
      switch code {
      case "user_not_found": return AuthenticationError.userNotFound
      case "wrong_password": return AuthenticationError.wrongPassword
      default: return AuthenticationError.invalidCredentials
      }
    case 403: return RequestFailure.forbidden
    case 404: return TrackerError.notFound
    case 405: return RequestFailure.unsupportedAction
    case 409:
      if code == "username_taken" || operation == .registration { return AuthenticationError.usernameTaken }
      return TrackerError.conflict("Есть связанные задачи, списки или теги. Сначала перенеси их или убери связь.")
    case 429: return AuthenticationError.rateLimited
    case 502, 503, 504: return SyncConnectionError.serverUnavailable
    default: return SyncConnectionError.internalFailure
    }
  }
}
