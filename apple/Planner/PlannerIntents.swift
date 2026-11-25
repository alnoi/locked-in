import AppIntents
import Foundation
import LockedInData
import LockedInDomain

@available(iOS 18.0, macOS 15.0, *)
enum QuickTaskTarget: String, AppEnum, URLRepresentableEnum {
  case newTask
  static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "TrackIt")
  static var caseDisplayRepresentations: [QuickTaskTarget: DisplayRepresentation] = [
    .newTask: "Новая задача"
  ]
  static var urlRepresentation: URLRepresentation { "lockedin://new-task" }
}

@available(iOS 18.0, macOS 15.0, *)
struct OpenQuickTaskIntent: OpenIntent {
  static var title: LocalizedStringResource = "Новая задача TrackIt"
  @Parameter(title: "Открыть") var target: QuickTaskTarget
  init() { target = .newTask }
  func perform() async throws -> some IntentResult { .result() }
}

struct CreateQuickTaskIntent: AppIntent {
  static var title: LocalizedStringResource = "Добавить задачу в TrackIt"
  static var description = IntentDescription("Сохранить задачу в общей доске без открытия приложения.")
  static var openAppWhenRun = false
  static var authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication
  @Parameter(title: "Название задачи", requestValueDialog: "Что нужно сделать?") var taskTitle: String
  static var parameterSummary: some ParameterSummary { Summary("Добавить \(\.$taskTitle) в TrackIt") }
  func perform() async throws -> some IntentResult & ProvidesDialog {
    do {
      guard let store = WidgetStore.shared, let context = try store.context() else {
        throw TrackerError.validation("Открой TrackIt и войди в аккаунт, чтобы подключить быстрое добавление.")
      }
      let synced = try await WidgetQuickTask.create(title: taskTitle, sourceKey: context.sourceKey, store: store)
      return .result(dialog: synced ? "Задача добавлена в TrackIt." : "Задача сохранена на устройстве. Синхронизируем при подключении TrackIt.")
    } catch {
      throw QuickTaskIntentError(message: UserFacingErrors.message(error))
    }
  }
}

private struct QuickTaskIntentError: LocalizedError {
  var message: String
  var errorDescription: String? { message }
}
