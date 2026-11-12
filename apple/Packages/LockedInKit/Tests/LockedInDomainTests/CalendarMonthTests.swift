import XCTest
@testable import LockedInDomain

final class CalendarMonthTests: XCTestCase {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Europe/Berlin")!
    return value
  }
  func testLeapFebruaryAndWholeMondayWeeks() {
    let date = calendar.date(from: DateComponents(year: 2024, month: 2, day: 10))!
    let days = CalendarMonth.days(containing: date, calendar: calendar)
    XCTAssertEqual(days.count % 7, 0)
    XCTAssertEqual(calendar.component(.weekday, from: days.first!), 2)
    XCTAssertEqual(calendar.component(.weekday, from: days.last!), 1)
    XCTAssertEqual(days.filter { calendar.component(.month, from: $0) == 2 }.count, 29)
  }
  func testSixWeeksAcrossDSTAndYearBoundary() {
    for parts in [DateComponents(year: 2026, month: 3, day: 12), DateComponents(year: 2026, month: 12, day: 12)] {
      let date = calendar.date(from: parts)!
      let days = CalendarMonth.days(containing: date, calendar: calendar)
      XCTAssertEqual(Set(days).count, days.count)
      XCTAssertEqual(days.filter { calendar.isDate($0, equalTo: date, toGranularity: .month) }.count, 31)
      for pair in zip(days, days.dropFirst()) {
        XCTAssertEqual(calendar.date(byAdding: .day, value: 1, to: pair.0), pair.1)
      }
    }
  }
}
