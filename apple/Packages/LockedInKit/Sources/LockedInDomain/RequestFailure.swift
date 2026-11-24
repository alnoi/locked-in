import Foundation

public enum RequestFailure: LocalizedError {
  case internalError, noConnection, forbidden, invalidRequest, unsupportedAction, invalidAttachment
  case invalidUsername, invalidPassword, invalidAvatar, invalidTimeZone, secureStorage, cancelled
  public var errorDescription: String? {
    switch self {
    case .invalidAttachment: "Не удалось прочитать скриншот. Выбери другую картинку."
    case .internalError: "Внутренняя ошибка. Обратись в поддержку."
    case .noConnection: "Нет связи с сервером. Проверь подключение и попробуй ещё раз."
    case .forbidden: "У тебя нет доступа к этому действию."
    case .invalidRequest: "Проверь заполненные поля и попробуй ещё раз."
    case .unsupportedAction: "Это действие пока не поддерживается. Обнови приложение."
    case .invalidUsername: "Логин — от 3 до 32 латинских букв, цифр, _ . −."
    case .invalidPassword: "Пароль — от 8 символов и не более 256 байт."
    case .invalidAvatar: "Выбери эмоджи для аватарки или оставь её пустой."
    case .invalidTimeZone: "Не удалось определить часовой пояс. Проверь настройки устройства."
    case .secureStorage: "Не удалось открыть защищённое хранилище аккаунта. Попробуй снова или обратись в поддержку."
    case .cancelled: "Запрос отменён. Попробуй ещё раз."
    }
  }
}
