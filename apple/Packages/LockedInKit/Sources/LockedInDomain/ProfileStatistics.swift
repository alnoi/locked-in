import Foundation

public enum ProfileStatisticsPeriod: String, CaseIterable, Identifiable, Sendable {
  case week, month, year
  public var id: Self { self }
  public var days: Int {
    switch self {
    case .week: 7
    case .month: 30
    case .year: 365
    }
  }
  var bucketComponent: Calendar.Component {
    switch self {
    case .week: .day
    case .month: .weekOfYear
    case .year: .month
    }
  }
}

public struct ProfileStatistics: Sendable {
  public struct Bucket: Identifiable, Sendable {
    public var id: Date { start }
    public let start: Date
    public let end: Date
    public let created: Int
  }
  public let period: ProfileStatisticsPeriod
  public let total: Int
  public let completed: Int
  public let overdue: Int
  public let active: Int
  public let unplanned: Int
  public let todayTotal: Int
  public let todayCompleted: Int
  public let buckets: [Bucket]
  public var weeklyAverage: Double { Double(total) * 7 / Double(period.days) }
  public var todayRemaining: Int { todayTotal - todayCompleted }

  public init(tasks: [TaskRecord], period: ProfileStatisticsPeriod = .month,
    now: Date = .now, calendar: Calendar = .current) {
    self.period = period
    let day = calendar.startOfDay(for: now)
    let start = calendar.date(byAdding: .day, value: 1 - period.days, to: day) ?? day
    let end = calendar.date(byAdding: .day, value: 1, to: day) ?? now
    let selected = tasks.filter { $0.createdAt >= start && $0.createdAt < end && $0.createdAt <= now }
    total = selected.count
    completed = selected.filter(\.completed).count
    active = total - completed
    overdue = selected.filter { WidgetAgenda.needsRescheduling($0, now: now, calendar: calendar) }.count
    unplanned = selected.filter { !$0.completed && $0.plannedAt == nil }.count
    let today = DayPlan.tasks(tasks, on: now, calendar: calendar)
    todayTotal = today.count
    todayCompleted = today.filter(\.completed).count
    var values: [Bucket] = []
    var cursor = start
    while cursor < end {
      let intervalEnd = calendar.dateInterval(of: period.bucketComponent, for: cursor)?.end ?? end
      let next = min(end, intervalEnd)
      guard next > cursor else { break }
      values.append(Bucket(start: cursor, end: next,
        created: selected.filter { $0.createdAt >= cursor && $0.createdAt < next }.count))
      cursor = next
    }
    buckets = values
  }
}
