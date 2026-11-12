import LockedInData
import LockedInDomain
import SwiftUI

struct SettingsView: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var tab = 0
  @State private var reminderTime = Calendar.current.date(
    bySettingHour: ReminderPreferences.dateOnlyMinutes / 60,
    minute: ReminderPreferences.dateOnlyMinutes % 60, second: 0, of: .now)!
  @State private var mode: StorageMode
  @State private var address: String
  @State private var message: String?
  @State private var testMessage: String?
  @State private var sendingTest = false
  @State private var working = false
  init(model: AppModel) {
    self.model = model
    _mode = State(initialValue: model.settings.mode)
    _address = State(initialValue: model.settings.serverAddress)
  }
  var body: some View {
    NavigationStack {
      TabView(selection: $tab) {
        storageForm.tabItem { Label("Общие", systemImage: "gearshape") }.tag(0)
        Form {
          Section("Задачи без точного времени") {
            Text("Во сколько напоминать").font(.headline)
            #if os(iOS)
              DatePicker(
                "Время уведомления", selection: $reminderTime, displayedComponents: [.hourAndMinute]
              ).datePickerStyle(.wheel).labelsHidden()
            #else
              DatePicker(
                "Время уведомления", selection: $reminderTime, displayedComponents: [.hourAndMinute]
              )
            #endif
            Text(
              "Если есть только дата дедлайна, обычное уведомление придёт в этот час. По умолчанию — 10:00. Будильник требует точного времени."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
          Section("Отладка") {
            Button(sendingTest ? "Отправка…" : "Отправить тестовое уведомление") {
              sendingTest = true
              testMessage = nil
              Task {
                defer { sendingTest = false }
                do {
                  try await model.alertScheduler.sendTestNotification()
                  testMessage = "Тестовое уведомление придёт через 5 секунд. Задача не создаётся."
                } catch { testMessage = model.friendly(error) }
              }
            }.disabled(sendingTest)
            if let testMessage = model.alertScheduler.testDeliveryStatus ?? testMessage {
              Text(testMessage).font(.caption).foregroundStyle(.secondary)
            }
          }
        }.formStyle(.grouped).tabItem { Label("Напоминания", systemImage: "bell") }.tag(1)
      }.navigationTitle("Настройки")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Закрыть") { dismiss() }.disabled(working || model.isLoading)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button(
              tab == 1 ? "Сохранить" : working || model.isLoading ? "Подключение…" : "Применить"
            ) {
              working = true
              Task {
                defer { working = false }
                do {
                  if tab == 1 {
                    let parts = Calendar.current.dateComponents(
                      [.hour, .minute], from: reminderTime)
                    ReminderPreferences.dateOnlyMinutes =
                      (parts.hour ?? 10) * 60 + (parts.minute ?? 0)
                    await model.refreshReminders()
                  } else {
                    try await model.connect(ConnectionSettings(mode: mode, serverAddress: address))
                  }
                  dismiss()
                } catch { message = model.friendly(error) }
              }
            }.disabled(working || model.isMutating || model.isLoading)
          }
        }
    }.interactiveDismissDisabled(working || model.isLoading)
      #if os(macOS)
        .frame(width: 520, height: 590)
      #endif
  }
  private var storageForm: some View {
    Form {
      Section {
        Picker("Хранение", selection: $mode) {
          ForEach(StorageMode.allCases) { Text($0.title).tag($0) }
        }.pickerStyle(.segmented)
        Text(
          mode == .local
            ? "Задачи сохраняются на этом устройстве и доступны без интернета."
            : "Изменения сохраняются в общей базе. На Mac и симуляторе iPhone можно использовать локальный сервер."
        )
        .font(.subheadline).foregroundStyle(.secondary)
      } header: {
        Text("Твоё пространство")
      } footer: {
        Text(
          "Локальные и серверные данные хранятся отдельно. Смена режима не переносит и не удаляет задачи."
        )
      }
      if mode == .server {
        Section {
          TextField("Адрес сервера", text: $address).autocorrectionDisabled()
          Text("http://127.0.0.1:8080").font(.caption.monospaced()).foregroundStyle(.secondary)
        } header: {
          Text("Подключение")
        } footer: {
          Text(
            "Текущий бэкенд доступен только на Mac. Для физического iPhone пока используй режим «На устройстве»."
          )
        }
      }
      if model.legacySource != nil {
        Section {
          Button("Импортировать задачи первой версии") {
            working = true
            Task {
              defer { working = false }
              do {
                let count = try await model.importLegacy()
                message =
                  count == 0
                  ? "Новых задач для импорта нет."
                  : "Импортировано задач: \(count). Исходные данные сохранены."
              } catch { message = model.friendly(error) }
            }
          }.disabled(!model.canEdit || working)
        } footer: {
          Text("Импорт в текущее пространство. Исходное SwiftData-хранилище остаётся на месте.")
        }
      }
      Section("О приложении") {
        LabeledContent("Locked In", value: "MVP · 0.2")
        Text("Задачи, идеи и время — в одном месте.").foregroundStyle(.secondary)
        if let date = model.lastRefresh {
          LabeledContent(
            "Последнее обновление", value: date.formatted(date: .omitted, time: .shortened))
        }
      }
      if let message { Section { Text(message).font(.callout) } }
    }.formStyle(.grouped)

  }
}
