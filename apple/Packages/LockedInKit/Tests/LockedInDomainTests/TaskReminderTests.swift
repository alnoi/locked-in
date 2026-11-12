import Foundation
import XCTest

@testable import LockedInDomain

final class TaskReminderTests: XCTestCase {
  private var calendar: Calendar {
    var value = Calendar(identifier: .gregorian)
    value.timeZone = TimeZone(identifier: "Europe/Moscow")!
    return value
  }
  func testPlannedStartHasPriorityAndLeadTimeIsSubtracted() {
    let planned = Date(timeIntervalSince1970: 2_000_000_000)
    let task = TaskRecord(
      input: TaskInput(
        title: "Task", deadlineAt: planned.addingTimeInterval(3600), plannedAt: planned,
        reminderMode: .alarm, reminderMinutesBefore: 5))
    XCTAssertEqual(TaskReminder.fireDate(for: task), planned.addingTimeInterval(-300))
  }
  func testDateOnlyUsesTenAndConfigurableTimeInLocalTimezone() {
    let task = TaskRecord(
      input: TaskInput(title: "Task", deadlineDate: "2030-03-31", reminderMode: .notification))
    let standard = TaskReminder.fireDate(for: task, calendar: calendar)!
    XCTAssertEqual(calendar.component(.hour, from: standard), 10)
    XCTAssertEqual(calendar.component(.day, from: standard), 31)
    let configured = TaskReminder.fireDate(
      for: task, calendar: calendar, dateOnlyMinutes: 8 * 60 + 35)!
    XCTAssertEqual(calendar.component(.hour, from: configured), 8)
    XCTAssertEqual(calendar.component(.minute, from: configured), 35)
  }
  func testCompletionAndDisablingCancelReminder() {
    var task = TaskRecord(
      input: TaskInput(title: "Task", deadlineAt: .now, reminderMode: .notification))
    XCTAssertNotNil(TaskReminder.fireDate(for: task))
    task.completed = true
    XCTAssertNil(TaskReminder.fireDate(for: task))
    task.completed = false
    task.reminderMode = ReminderMode.none
    XCTAssertNil(TaskReminder.fireDate(for: task))
  }
  func testAlarmRequiresExactTimeAndFallsBackToDeadline() throws {
    let dateOnly = TaskInput(title: "Task", deadlineDate: "2030-03-31", reminderMode: .alarm)
    XCTAssertThrowsError(try TrackerRules.validate(dateOnly, id: nil, in: Snapshot()))
    XCTAssertNil(TaskReminder.fireDate(for: TaskRecord(input: dateOnly), calendar: calendar))
    let date = Date(timeIntervalSince1970: 2_000_000_000)
    var timed = dateOnly
    timed.deadlineDate = nil
    timed.deadlineAt = date
    try TrackerRules.validate(timed, id: nil, in: Snapshot())
    XCTAssertEqual(TaskReminder.fireDate(for: TaskRecord(input: timed)), date)
  }
  func testModeCyclesAndInputCopyPreservesReminder() {
    XCTAssertEqual(ReminderMode.none.next, .notification)
    XCTAssertEqual(ReminderMode.notification.next, .alarm)
    XCTAssertEqual(ReminderMode.alarm.next, .none)
    let input = TaskInput(
      title: "Task", plannedAt: .now, reminderMode: .alarm, reminderMinutesBefore: 15)
    XCTAssertEqual(TaskInput(TaskRecord(input: input)), input)
  }
}
