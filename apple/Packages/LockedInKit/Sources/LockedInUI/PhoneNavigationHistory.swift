import Foundation

enum PhoneScreen: Hashable {
  case menu
  case section(Destination)
}

struct PhoneCalendarPosition: Equatable {
  var date: Date
  var monthMode: Bool
}

struct PhoneNavigationEntry {
  var screen: PhoneScreen
  var calendarFocus: CalendarTaskFocus?
  var calendarPosition: PhoneCalendarPosition?
}

// A chronological journal, independent of the desktop's Control-Tab MRU list.
struct PhoneNavigationHistory {
  private var entries: [PhoneNavigationEntry]
  private var index: Int
  var current: PhoneNavigationEntry { entries[index] }
  var canGoBack: Bool { index > 0 }
  var canGoForward: Bool { index + 1 < entries.count }

  init(initial: Destination = .board) {
    entries = [PhoneNavigationEntry(screen: .menu), PhoneNavigationEntry(screen: .section(initial))]
    index = 1
  }
  mutating func visit(_ screen: PhoneScreen, calendarFocus: CalendarTaskFocus? = nil) {
    guard screen != current.screen else { return }
    entries.removeSubrange((index + 1)..<entries.count)
    entries.append(PhoneNavigationEntry(screen: screen, calendarFocus: calendarFocus))
    index = entries.count - 1
  }
  mutating func rememberCalendar(_ position: PhoneCalendarPosition, focus: CalendarTaskFocus?) {
    guard current.screen == .section(.calendar) else { return }
    guard current.calendarPosition != position || current.calendarFocus != focus else { return }
    entries[index].calendarPosition = position
    entries[index].calendarFocus = focus
  }
  mutating func back() -> PhoneNavigationEntry? {
    guard canGoBack else { return nil }
    index -= 1
    return current
  }
  mutating func forward() -> PhoneNavigationEntry? {
    guard canGoForward else { return nil }
    index += 1
    return current
  }
}
