import LockedInDomain
import XCTest
@testable import LockedInData

final class TaskOrderingTests: XCTestCase {
  func testSavedOrderSurvivesReloadAndNewTasksAppend() {
    let suite = "TaskOrderTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let user = UUID()
    let a = TaskRecord(input: TaskInput(title: "A"), createdAt: Date(timeIntervalSince1970: 1))
    let b = TaskRecord(input: TaskInput(title: "B"), createdAt: Date(timeIntervalSince1970: 2))
    let c = TaskRecord(input: TaskInput(title: "C"), createdAt: Date(timeIntervalSince1970: 3))
    TaskOrderPreferences.save([b.id, a.id], space: "server", userID: user, defaults: defaults)
    let reopened = UserDefaults(suiteName: suite)!
    XCTAssertEqual(TaskOrderPreferences.orderedIDs([c, a, b], space: "server", userID: user, defaults: reopened), [b.id, a.id, c.id])
    XCTAssertEqual(TaskOrderPreferences.orderedIDs([c, b], space: "server", userID: user, defaults: reopened), [b.id, c.id])
    XCTAssertEqual(TaskOrderPreferences.orderedIDs([b, a], space: "local", userID: user, defaults: reopened), [a.id, b.id])
    XCTAssertEqual(TaskOrderPreferences.orderedIDs([b, a], space: "server", userID: UUID(), defaults: reopened), [a.id, b.id])
  }
  func testFilteredBoardReorderPreservesHiddenTasks() {
    let a = UUID(), hidden = UUID(), b = UUID(), otherList = UUID()
    let current = [a, hidden, b, otherList]
    XCTAssertEqual(TaskOrderPreferences.merging([b, a], into: current), [b, hidden, a, otherList])
    XCTAssertEqual(TaskOrderPreferences.merging([a, a], into: current), current)
    XCTAssertEqual(TaskOrderPreferences.merging([UUID()], into: current), current)
  }
}
