import AppIntents
import LockedInWidgetUI
import LockedInUI
import SwiftUI
#if os(iOS)
import UserNotifications
#endif

@main
struct PlannerApp: App {
  @AppStorage(AppTheme.preferenceKey) private var theme: AppTheme = .system
  @State private var model = AppModel(legacySource: LegacyStore.read)
  #if os(iOS)
  init() {
    Task { await Self.removeOldCaptureNotifications() }
  }
  private static func removeOldCaptureNotifications() async {
    let key = "trackit.quick-task.notification-prototype-removed"
    guard !UserDefaults.standard.bool(forKey: key) else { return }
    let center = UNUserNotificationCenter.current()
    let pending = await center.pendingNotificationRequests()
    let delivered = await center.deliveredNotifications()
    let pendingIDs = pending.filter { $0.identifier.hasPrefix("trackit.quick-task.") }.map(\.identifier)
    let deliveredIDs = delivered.filter { $0.request.identifier.hasPrefix("trackit.quick-task.") }.map { $0.request.identifier }
    center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
    center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    UserDefaults.standard.set(true, forKey: key)
  }
  #endif
  var body: some Scene {
    WindowGroup("TrackIt") {
      LockedInRootView(model: model)
        .trackItAccent()
        .trackItTheme(theme)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        #if os(macOS)
          .frame(minWidth: 760, minHeight: 620)
          .handlesExternalEvents(preferring: ["lockedin://"], allowing: ["lockedin://"])
        #endif
    }
    .defaultSize(width: 1200, height: 820)
    #if os(macOS)
      MenuBarExtra("TrackIt", systemImage: "scope") {
        MacQuickAccessView(model: model)
          .trackItAccent()
          .trackItTheme(theme)
          .environment(\.locale, Locale(identifier: "ru_RU"))
      }.menuBarExtraStyle(.window)
      Window("Будильник", id: "task-alarm") {
        ReminderAlarmView(scheduler: model.alertScheduler)
          .trackItAccent()
          .trackItTheme(theme)
      }.windowResizability(.contentSize).defaultPosition(.center)
    #endif
  }
}

struct TrackItShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(intent: CreateQuickTaskIntent(), phrases: [
      "Добавь задачу в \(.applicationName)",
      "Новая задача в \(.applicationName)"
    ], shortTitle: "Добавить задачу", systemImageName: "plus.circle")
  }
}
