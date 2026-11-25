import AppIntents
import LockedInWidgetUI
import SwiftUI
import WidgetKit

@main
struct LockedInWidgets: WidgetBundle {
  var body: some Widget {
    #if os(macOS)
    if #available(macOS 26.0, *) { QuickTaskControl() }
    #endif
    TodayWidget()
    CalendarWidget()
    #if os(iOS)
    TaskLiveActivityWidget()
    #endif
  }
}

#if os(macOS)
@available(macOS 26.0, *)
struct QuickTaskControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "TrackIt.NewTask") {
      ControlWidgetButton(action: OpenQuickTaskIntent()) {
        Label("Новая задача", systemImage: "plus.circle")
      }
    }
    .displayName("Новая задача")
    .description("Открыть добавление задачи в общей доске TrackIt.")
  }
}
#endif
