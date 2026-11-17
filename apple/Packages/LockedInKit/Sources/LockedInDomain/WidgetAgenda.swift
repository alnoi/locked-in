import Foundation

public enum WidgetAgenda {
  public static func isOverdue(_ task: TaskRecord, now: Date = .now, calendar: Calendar = .current) -> Bool {
    if let date = task.deadlineAt { return date < now }
    return task.deadlineDate.map { $0 < dayKey(now, calendar: calendar) } ?? false
  }
  public static func needsRescheduling(_ task: TaskRecord, now: Date = .now, calendar: Calendar = .current) -> Bool {
    guard !task.completed else { return false }
    return isOverdue(task, now: now, calendar: calendar)
      || task.plannedAt.map { $0 < calendar.startOfDay(for: now) } == true
  }
  public static func today(_ tasks: [TaskRecord], now: Date = .now, calendar: Calendar = .current,
    includeCompleted: Bool = false) -> [TaskRecord] {
    let start = calendar.startOfDay(for: now)
    let end = calendar.date(byAdding: .day, value: 1, to: start)!
    return tasks.filter { task in
      guard !task.completed || (includeCompleted && calendar.isDate(task.updatedAt, inSameDayAs: now)) else { return false }
      guard task.completed || !isOverdue(task, now: now, calendar: calendar) else { return false }
      return task.plannedAt.map { $0 >= start && $0 < end } == true
    }.sorted { left, right in
      let a = isOverdue(left, now: now, calendar: calendar)
      let b = isOverdue(right, now: now, calendar: calendar)
      if a != b { return a }
      let first = left.plannedAt ?? left.deadlineAt ?? end
      let second = right.plannedAt ?? right.deadlineAt ?? end
      if first != second { return first < second }
      return left.createdAt < right.createdAt
    }
  }
  public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }
  public static func calendarURL(_ date: Date) -> URL {
    URL(string: "lockedin://calendar?date=" + dayKey(date))!
  }
  public static func taskURL(_ id: UUID) -> URL { URL(string: "lockedin://task/" + id.uuidString)! }
}
