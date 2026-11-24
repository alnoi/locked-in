import Foundation

public struct AuthSession: Codable, Sendable {
  public var user: UserRecord
  public var accessToken: String
  public var expiresAt: Date
  public init(user: UserRecord, accessToken: String, expiresAt: Date) {
    self.user = user; self.accessToken = accessToken; self.expiresAt = expiresAt
  }
}

public enum AuthenticationError: LocalizedError, Equatable {
  case invalidCredentials, usernameTaken, sessionExpired, invalidRegistration, rateLimited
  public var errorDescription: String? {
    switch self {
    case .invalidCredentials: return "Неверный логин или пароль."
    case .usernameTaken: return "Этот логин уже занят."
    case .sessionExpired: return "Войди в аккаунт ещё раз. Твои данные сохранены."
    case .invalidRegistration: return "Проверь логин, пароль и эмоджи."
    case .rateLimited: return "Слишком много попыток. Подожди минуту и попробуй снова."
    }
  }
}

public enum ProfileEmoji {
  public static func valid(_ value: String) -> Bool {
    value.count == 1 && value.unicodeScalars.contains {
      ($0.properties.isEmoji && $0.value > 127) || $0.value == 0x20E3
    } && !value.unicodeScalars.contains { $0.properties.generalCategory == .control }
  }
}
