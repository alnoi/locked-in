import LockedInWidgetUI
import SwiftUI
import WidgetKit

@main
struct LockedInWidgets: WidgetBundle {
  var body: some Widget {
    TodayWidget()
    CalendarWidget()
    #if os(iOS)
    TaskLiveActivityWidget()
    #endif
  }
}
