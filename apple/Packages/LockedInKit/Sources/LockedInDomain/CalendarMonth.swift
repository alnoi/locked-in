import Foundation

public enum CalendarMonth {
  public static func days(containing date: Date, calendar: Calendar = .current) -> [Date] {
    guard let month = calendar.dateInterval(of: .month, for: date),
      let count = calendar.range(of: .day, in: .month, for: date)?.count else { return [] }
    let leading = (calendar.component(.weekday, from: month.start) + 5) % 7
    guard let start = calendar.date(byAdding: .day, value: -leading, to: month.start) else { return [] }
    let cells = ((leading + count + 6) / 7) * 7
    return (0..<cells).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }
}
