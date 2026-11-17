import Foundation
import XCTest
@testable import LockedInDomain

final class WidgetAgendaTests: XCTestCase {
  func testTodayIncludesPlannedTasksAndDeadlinesButNotTomorrowOrCompleted() throws {
    var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let now = ISO8601DateFormatter().date(from: "2026-11-18T12:00:00Z")!
    let planned = TaskRecord(input: TaskInput(title: "Planned", plannedAt: now.addingTimeInterval(3600)))
    let overdue = TaskRecord(input: TaskInput(title: "Overdue", deadlineDate: "2026-11-17"))
    let dueToday = TaskRecord(input: TaskInput(title: "Today", deadlineDate: "2026-11-18"))
    let dueTime = TaskRecord(input: TaskInput(title: "Timed", deadlineAt: now.addingTimeInterval(7200)))
    let future = TaskRecord(input: TaskInput(title: "Tomorrow", plannedAt: now.addingTimeInterval(86400)))
    let undated = TaskRecord(input: TaskInput(title: "Undated"))
    var done = TaskRecord(input: TaskInput(title: "Done", plannedAt: now), completed: true)
    done.updatedAt = now
    var oldDone = TaskRecord(input: TaskInput(title: "Done earlier", deadlineDate: "2026-11-17"), completed: true)
    oldDone.updatedAt = now.addingTimeInterval(-86400)
    let tasks = [planned, overdue, dueToday, dueTime, future, undated, done, oldDone]
    let visible = WidgetAgenda.today(tasks, now: now, calendar: calendar)
    XCTAssertEqual(Set(visible.map(\.id)), Set([planned.id, overdue.id, dueToday.id, dueTime.id]))
    XCTAssertEqual(visible.first?.id, overdue.id)
    XCTAssertFalse(WidgetAgenda.isOverdue(dueToday, now: now, calendar: calendar))
    XCTAssertTrue(WidgetAgenda.today(tasks, now: now, calendar: calendar, includeCompleted: true).contains { $0.id == done.id })
    XCTAssertFalse(WidgetAgenda.today(tasks, now: now, calendar: calendar, includeCompleted: true).contains { $0.id == oldDone.id })
    let tomorrow = WidgetAgenda.today(tasks, now: now.addingTimeInterval(86400), calendar: calendar)
    XCTAssertTrue(tomorrow.contains { $0.id == future.id })
    XCTAssertFalse(tomorrow.contains { $0.id == planned.id })
  }
}
