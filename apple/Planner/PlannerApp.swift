import LockedInUI
import SwiftUI

@main
struct PlannerApp: App {
  @State private var model = AppModel(legacySource: LegacyStore.read)
  var body: some Scene {
    WindowGroup("Locked In") {
      LockedInRootView(model: model)
        .environment(\.locale, Locale(identifier: "ru_RU"))
        #if os(macOS)
          .frame(minWidth: 760, minHeight: 620)
        #endif
    }
    .defaultSize(width: 1200, height: 820)
    #if os(macOS)
      Window("Будильник", id: "task-alarm") {
        ReminderAlarmView(scheduler: model.alertScheduler)
      }.windowResizability(.contentSize).defaultPosition(.center)
    #endif
  }
}
