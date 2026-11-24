import LockedInData
import LockedInDomain
import SwiftUI

struct SettingsView: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @AppStorage(AppTheme.preferenceKey) private var savedTheme: AppTheme = .system
  @AppStorage(AppAccent.preferenceKey) private var savedAccent: AppAccent = .violet
  @State private var section = SettingsSection.general
  @State private var theme: AppTheme
  @State private var accent: AppAccent
  @State private var workdayStart: Date
  @State private var workdayEnd: Date
  @State private var reminderTime: Date
  @State private var mode: StorageMode
  @State private var address: String
  @State private var message: String?
  @State private var testMessage: String?
  @State private var sendingTest = false
  @State private var working = false
  @State private var pinging = false
  @State private var pingSucceeded: Bool?

  init(model: AppModel) {
    self.model = model
    _accent = State(initialValue: UserDefaults.standard.string(forKey: AppAccent.preferenceKey).flatMap(AppAccent.init) ?? .violet)
    _theme = State(initialValue: UserDefaults.standard.string(forKey: AppTheme.preferenceKey).flatMap(AppTheme.init) ?? .system)
    _workdayStart = State(initialValue: Self.time(WorkdayPreferences.startMinutes))
    _workdayEnd = State(initialValue: Self.time(WorkdayPreferences.endMinutes))
    _reminderTime = State(initialValue: Self.time(ReminderPreferences.dateOnlyMinutes))
    _mode = State(initialValue: model.settings.mode)
    _address = State(initialValue: model.settings.serverAddress)
  }

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text("Настройки").font(.system(size: 15, weight: .semibold))
        Spacer()
        Button { dismiss() } label: {
          Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary).frame(width: 28, height: 28)
            .background(Color.primary.opacity(0.06), in: Circle())
        }.buttonStyle(.plain).accessibilityLabel("Закрыть настройки")
          .keyboardShortcut(.cancelAction).disabled(busy)
      }.padding(.horizontal, 22).padding(.vertical, 14)
      Divider()
      #if os(macOS)
      HStack(spacing: 0) {
        sidebar.frame(width: 182)
        Divider()
        detail
      }
      #else
      VStack(spacing: 0) {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 6) { ForEach(SettingsSection.allCases) { sectionButton($0) } }
            .padding(12)
        }
        detail
      }
      #endif
      Divider()
      footer
    }
    .background(.regularMaterial)
    .interactiveDismissDisabled(busy)
    .dismissOnOutsideClick(enabled: !busy && !model.isMutating)
    .submitOnEnter(enabled: !busy && !model.isMutating) { Task { await saveSettings() } }
    #if os(macOS)
    .frame(width: 760, height: 650)
    #endif
  }

  private var busy: Bool { working || model.isLoading }
  private var connectionChanged: Bool { mode != model.settings.mode || address != model.settings.serverAddress }
  private var hasChanges: Bool {
    theme != savedTheme || accent != savedAccent || Self.minutes(workdayStart) != WorkdayPreferences.startMinutes
      || Self.minutes(workdayEnd) != WorkdayPreferences.endMinutes
      || Self.minutes(reminderTime) != ReminderPreferences.dateOnlyMinutes || connectionChanged
  }
  private var sidebar: some View {
    VStack(alignment: .leading, spacing: 6) {
      ForEach(SettingsSection.allCases) { sectionButton($0) }
      Spacer()
      VStack(alignment: .leading, spacing: 4) {
        Text("TrackIt").font(.system(size: 13, weight: .semibold))
        Text("Make room for your life.").font(.system(size: 10)).foregroundStyle(.secondary)
      }.padding(10)
    }.padding(12).background(Color.primary.opacity(0.025))
  }
  private func sectionButton(_ item: SettingsSection) -> some View {
    Button {
      withAnimation(reduceMotion ? nil : .easeOut(duration: 0.12)) { section = item }
    } label: {
      HStack(spacing: 10) {
        Image(systemName: item.symbol).frame(width: 18)
        Text(item.title).font(.system(size: 12, weight: section == item ? .semibold : .medium))
        #if os(macOS)
        Spacer(minLength: 0)
        #endif
      }.padding(.horizontal, 11).padding(.vertical, 12)
        .foregroundStyle(section == item ? Color.accent : Color.primary.opacity(0.75))
        .background(section == item ? Color.accent.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 11))
        .contentShape(RoundedRectangle(cornerRadius: 11))
    }.buttonStyle(.plain).accessibilityAddTraits(section == item ? .isSelected : [])
  }
  private var detail: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        VStack(alignment: .leading, spacing: 6) {
          Text(section.title).font(.system(size: 25, weight: .bold))
          Text(section.subtitle).font(.system(size: 13)).foregroundStyle(.secondary)
        }.padding(.bottom, 2)
        Group {
          switch section {
          case .general: generalSettings
          case .notifications: notificationSettings
          case .shortcuts: ShortcutGuide()
          case .connection: connectionSettings
          }
        }.disabled(working)
      }.frame(maxWidth: .infinity, alignment: .leading).padding(26)
    }.id(section)
  }
  private var generalSettings: some View {
    VStack(spacing: 24) {
      SettingsCard(title: "Оформление") {
        HStack(spacing: 8) {
          ForEach(AppTheme.allCases) { item in
            Button { theme = item } label: {
              VStack(spacing: 10) {
                Image(systemName: item.symbol).font(.system(size: 24, weight: .light))
                Text(item.title).font(.system(size: 11, weight: .medium))
              }.frame(maxWidth: .infinity).padding(.vertical, 16)
                .foregroundStyle(theme == item ? Color.accent : .secondary)
                .background(theme == item ? Color.accent.opacity(0.1) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme == item ? Color.accent.opacity(0.5) : .clear))
                .contentShape(RoundedRectangle(cornerRadius: 12))
            }.buttonStyle(.plain).accessibilityAddTraits(theme == item ? .isSelected : [])
          }
        }
      }
      SettingsCard(title: "Цвет темы", caption: "По умолчанию — фиолетовый TrackIt.") {
        AccentColorSelection(selected: $accent)
      }
      SettingsCard(title: "Рабочий день", caption: "В конце дня напомним, сколько запланированных задач осталось. Если всё сделано — без уведомления.") {
        SettingsTimeRow(title: "Начало", symbol: "sunrise", value: $workdayStart)
        Divider()
        SettingsTimeRow(title: "Конец", symbol: "sunset", value: $workdayEnd)
      }
      Text("Эти настройки сохраняются на этом устройстве отдельно для каждого аккаунта.")
        .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
    }
  }
  private var notificationSettings: some View {
    VStack(spacing: 24) {
      SettingsCard(title: "Дедлайн без времени", caption: "Если у задачи есть только дата, напоминание придёт в этот час. По умолчанию — в 10:00.") {
        SettingsTimeRow(title: "Напоминать в", symbol: "bell", value: $reminderTime)
      }
      SettingsCard(title: "Как это работает") {
        Label("Сначала — время планирования. Если его нет — дедлайн.", systemImage: "calendar.badge.clock")
        Divider()
        Label("Будильник доступен только для задач с точным временем.", systemImage: "alarm")
      }.font(.system(size: 13)).foregroundStyle(.secondary)
      SettingsCard(title: "Проверка уведомлений") {
        Button(sendingTest ? "Отправка…" : "Отправить тестовое уведомление", systemImage: "paperplane") { sendTest() }
          .buttonStyle(.bordered).disabled(sendingTest)
        Text(model.alertScheduler.testDeliveryStatus ?? testMessage ?? "Придёт через 5 секунд. Новая задача не создаётся.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }
  }
  private var connectionSettings: some View {
    VStack(spacing: 24) {
      SettingsCard(title: "Сервер", caption: "Проверка соединения не меняет адрес. Чтобы применить изменения, нажми «Сохранить».") {
        TextField("https://…", text: $address).textFieldStyle(.plain).font(.system(size: 13, design: .monospaced))
          .padding(12).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
          .autocorrectionDisabled().onSubmit { Task { await saveSettings() } }
          .onChange(of: address) { _, _ in pingSucceeded = nil }
        HStack(spacing: 10) {
          Button("Установить соединение", action: ping).buttonStyle(.bordered).disabled(pinging || working)
          if pinging { ProgressView().controlSize(.small) }
          if let pingSucceeded {
            Label(pingSucceeded ? "success" : "fail", systemImage: pingSucceeded ? "checkmark.circle.fill" : "xmark.circle.fill")
              .font(.system(size: 12, weight: .medium)).foregroundStyle(pingSucceeded ? Color.green : Color.red)
          }
        }
      }
      SettingsCard(title: "Синхронизация") {
        Label(model.settings.mode == .local ? "Данные на этом устройстве" : model.isOffline ? "Нет связи с сервером" : "Подключено к серверу",
          systemImage: model.settings.mode == .local ? "internaldrive" : model.isOffline ? "wifi.slash" : "checkmark.icloud")
          .font(.system(size: 13))
        if let date = model.lastRefresh {
          LabeledContent("Последнее обновление", value: date.formatted(date: .omitted, time: .shortened))
            .font(.caption).foregroundStyle(.secondary)
        }
        Text("Задачи можно менять без сети — изменения отправятся при подключении. Для досок, списков и тегов нужна связь.")
          .font(.caption).foregroundStyle(.secondary)
      }
      SettingsCard(title: "Дополнительно") {
        DisclosureGroup("Хранение и перенос данных") {
          VStack(alignment: .leading, spacing: 14) {
            Picker("Хранение", selection: $mode) {
              ForEach(StorageMode.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Text("Режим «На устройстве» — отдельное пространство без серверного аккаунта. Смена режима не переносит и не удаляет задачи.")
              .font(.caption).foregroundStyle(.secondary)
            if model.legacySource != nil {
              Button("Импортировать задачи первой версии", action: importLegacy).disabled(!model.canEdit || working)
            }
          }.padding(.top, 12)
        }.font(.system(size: 13))
      }
    }
  }
  private var footer: some View {
    HStack(spacing: 12) {
      if let message {
        Text(message).font(.caption).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
      } else {
        Text(hasChanges ? "Есть несохранённые изменения" : "Всё настроено")
          .font(.caption).foregroundStyle(.secondary)
      }
      Spacer(minLength: 4)
      if working { ProgressView().controlSize(.small) }
      Button(hasChanges ? "Отмена" : "Готово") { dismiss() }.disabled(busy)
      if hasChanges {
        Button("Сохранить") { Task { await saveSettings() } }
          .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
          .disabled(busy || model.isMutating)
      }
    }.padding(.horizontal, 22).padding(.vertical, 16)
  }
  private func saveSettings() async {
    guard !busy, !model.isMutating else { return }
    guard hasChanges else { dismiss(); return }
    guard Self.minutes(workdayEnd) > Self.minutes(workdayStart) else {
      section = .general
      message = "Конец рабочего дня должен быть позже начала."
      return
    }
    working = true
    message = nil
    defer { working = false }
    do {
      WorkdayPreferences.startMinutes = Self.minutes(workdayStart)
      WorkdayPreferences.endMinutes = Self.minutes(workdayEnd)
      ReminderPreferences.dateOnlyMinutes = Self.minutes(reminderTime)
      savedTheme = theme
      savedAccent = accent
      await model.refreshReminders()
      if connectionChanged {
        try await model.connect(ConnectionSettings(mode: mode, serverAddress: address,
          accountID: AuthSessionStore.activeUserID(address: address)))
      }
      dismiss()
    } catch { message = model.friendly(error) }
  }
  private func ping() {
    let target = address
    pinging = true
    pingSucceeded = nil
    message = nil
    Task {
      defer { pinging = false }
      do {
        try await AuthenticationClient(address: target).ping()
        if address == target { pingSucceeded = true }
      } catch {
        if address == target { pingSucceeded = false; message = model.friendly(error) }
      }
    }
  }
  private func sendTest() {
    sendingTest = true
    testMessage = nil
    Task {
      defer { sendingTest = false }
      do {
        try await model.alertScheduler.sendTestNotification()
        testMessage = "Тестовое уведомление придёт через 5 секунд."
      } catch { testMessage = model.friendly(error) }
    }
  }
  private func importLegacy() {
    working = true
    Task {
      defer { working = false }
      do {
        let count = try await model.importLegacy()
        message = count == 0 ? "Новых задач для импорта нет." : "Импортировано задач: \(count). Исходные данные сохранены."
      } catch { message = model.friendly(error) }
    }
  }
  private static func minutes(_ date: Date) -> Int {
    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
  }
  private static func time(_ minutes: Int) -> Date {
    Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
  }
}
