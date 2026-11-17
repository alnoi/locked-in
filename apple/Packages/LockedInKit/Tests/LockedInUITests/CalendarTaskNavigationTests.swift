import Foundation
import LockedInDomain
import XCTest
@testable import LockedInUI

final class CalendarTaskNavigationTests: XCTestCase {
  func testUnschedulingKeepsTaskDeadlineDurationAndOtherFields() {
    let task = TaskRecord(input: TaskInput(title: "Keep task", description: "https://example.com",
      listID: UUID(), deadlineDate: "2026-11-20", plannedAt: Date(timeIntervalSince1970: 2000),
      durationMinutes: 90, tagIDs: [UUID()]))
    var expected = TaskInput(task)
    expected.plannedAt = nil
    XCTAssertEqual(CalendarTaskNavigation.unschedule(task), expected)
  }

  func testUnplannedTaskIsScheduledNowForOneHourAndKeepsOtherFields() throws {
    let now = Date(timeIntervalSince1970: 2000)
    let task = TaskRecord(input: TaskInput(title: "Task", description: "https://example.com",
      listID: UUID(), parentID: UUID(), deadlineDate: "2026-11-20", durationMinutes: 15, tagIDs: [UUID()]))
    let planned = try XCTUnwrap(CalendarTaskNavigation.planIfNeeded(task, now: now))
    XCTAssertEqual(planned.plannedAt, now)
    XCTAssertEqual(planned.durationMinutes, 60)
    var expected = TaskInput(task)
    expected.plannedAt = now
    expected.durationMinutes = 60
    XCTAssertEqual(planned, expected)
  }
  func testOpeningScheduledTaskDoesNotRescheduleOrChangeItsDuration() {
    let task = TaskRecord(input: TaskInput(title: "Existing", plannedAt: Date(timeIntervalSince1970: 1000), durationMinutes: 90))
    XCTAssertNil(CalendarTaskNavigation.planIfNeeded(task, now: Date(timeIntervalSince1970: 2000)))
  }
}
