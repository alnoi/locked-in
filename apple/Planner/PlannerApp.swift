import LockedInWidgetUI
import LockedInUI
import SwiftUI

@main
struct PlannerApp: App {
  @AppStorage(AppTheme.preferenceKey) private var theme: AppTheme = .system
  @State private var model = AppModel(legacySource: LegacyStore.read)
  var body: some Scene {
    WindowGroup("TrackIt") {
      LockedInRootView(model: model)
        .trackItAccent()
        .preferredColorScheme(theme.colorScheme)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        #if os(macOS)
          .frame(minWidth: 760, minHeight: 620)
          .handlesExternalEvents(preferring: ["lockedin://"], allowing: ["lockedin://"])
        #endif
    }
    .defaultSize(width: 1200, height: 820)
    #if os(macOS)
      Window("Будильник", id: "task-alarm") {
        ReminderAlarmView(scheduler: model.alertScheduler)
          .trackItAccent()
          .bugReportAccess(model: model, reserveSpace: true)
          .preferredColorScheme(theme.colorScheme)
      }.windowResizability(.contentSize).defaultPosition(.center)
    #endif
  }
}
