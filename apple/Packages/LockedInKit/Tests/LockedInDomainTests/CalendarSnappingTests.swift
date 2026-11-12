import XCTest
@testable import LockedInDomain

final class CalendarSnappingTests: XCTestCase {
  func testQuarterHoursAndHourRollover() {
    XCTAssertEqual(CalendarSnapping.minute(58, boundaries: []), 60)
    XCTAssertEqual(CalendarSnapping.minute(607, boundaries: []), 600)
    XCTAssertEqual(CalendarSnapping.minute(608, boundaries: []), 615)
  }
  func testNeighborTakesPriorityOnlyWithinMagnetRange() {
    XCTAssertEqual(CalendarSnapping.minute(610, boundaries: [612]), 612)
    XCTAssertEqual(CalendarSnapping.minute(620, boundaries: [612]), 615)
    XCTAssertEqual(CalendarSnapping.minute(609, boundaries: [612, 607]), 607)
  }
  func testResizeAndDayBounds() {
    XCTAssertEqual(CalendarSnapping.minute(602, boundaries: [600], minimum: 615, maximum: 1440), 615)
    XCTAssertEqual(CalendarSnapping.minute(1455, boundaries: [], maximum: 1380), 1380)
    XCTAssertEqual(CalendarSnapping.minute(-20, boundaries: []), 0)
  }
}
