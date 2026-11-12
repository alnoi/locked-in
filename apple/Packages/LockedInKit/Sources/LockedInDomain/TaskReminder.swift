import Foundation

public enum ReminderMode: String, Codable, Sendable, CaseIterable {
  case none, notification, alarm
  public var next: Self { self == .none ? .notification : self == .notification ? .alarm : .none }
  public var title: String {
    self == .none ? "Выключено" : self == .notification ? "Уведомление" : "Будильник"
  }
  public var symbol: String {
    self == .alarm ? "alarm.fill" : self == .notification ? "bell.fill" : "bell.slash"
  }
}
public enum TaskReminder {
  public static let offsets = [0, 5, 10, 15, 30, 60, 1440]
  public static func offsetTitle(_ minutes: Int) -> String {
    if minutes == 0 { return "В момент события" }
    if minutes == 60 { return "За час" }
    if minutes == 1440 { return "За день" }
    return "За \(minutes) мин"
  }
  public static func fireDate(
    for task: TaskRecord, calendar: Calendar = .current, dateOnlyMinutes: Int = 600
  ) -> Date? {
    guard !task.completed, (task.reminderMode ?? .none) != .none else { return nil }
    let event: Date?
    if let planned = task.plannedAt {
      event = planned
    } else if let deadline = task.deadlineAt {
      event = deadline
    } else if let value = task.deadlineDate {
      guard task.reminderMode != .alarm else { return nil }
      let components = value.split(separator: "-").compactMap { Int($0) }
      guard components.count == 3 else { return nil }
      event = calendar.date(
        from: DateComponents(
          year: components[0], month: components[1], day: components[2], hour: dateOnlyMinutes / 60,
          minute: dateOnlyMinutes % 60))
    } else {
      event = nil
    }
    return event?.addingTimeInterval(-Double(task.reminderMinutesBefore ?? 0) * 60)
  }
}
