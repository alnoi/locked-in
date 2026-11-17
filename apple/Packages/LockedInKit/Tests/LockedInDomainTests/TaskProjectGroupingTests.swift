import XCTest
@testable import LockedInDomain

final class TaskProjectGroupingTests: XCTestCase {
  func testProjectHasOneRootRegardlessOfTaskOrder() {
    let project = TaskRecord(input: TaskInput(title: "Project"))
    let child = TaskRecord(input: TaskInput(title: "Child", parentID: project.id))
    let other = TaskRecord(input: TaskInput(title: "Other"))
    let all = [child, project, other]
    XCTAssertEqual(TaskProjectGrouping.roots(visible: all, all: all).map(\.id), [project.id, other.id])
    XCTAssertEqual(TaskProjectGrouping.roots(visible: [child], all: all).map(\.id), [project.id])
  }
  func testChildUsesProjectListAfterProjectMoves() {
    let oldList = UUID(), newList = UUID()
    let project = TaskRecord(input: TaskInput(title: "Project", listID: newList))
    let child = TaskRecord(input: TaskInput(title: "Child", listID: oldList, parentID: project.id))
    XCTAssertEqual(TaskProjectGrouping.listID(of: child, in: [project, child]), newList)
    XCTAssertEqual(TaskProjectGrouping.listID(of: child, in: [child]), oldList)
  }
}
