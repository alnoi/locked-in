import XCTest
import LockedInDomain
@testable import LockedInUI

final class TaskPlacementTests: XCTestCase {
  @MainActor
  func testEndPreviewMovesAfterTheLastProjectAndSupportsEmptyLists() async throws {
    let destination = UUID()
    let moving = TaskRecord(input: TaskInput(title: "Moving"))
    let project = TaskRecord(input: TaskInput(title: "Project", listID: destination, isProject: true))
    let child = TaskRecord(input: TaskInput(title: "Child", listID: destination, parentID: project.id))
    let session = BoardReorderSession(kind: .task)
    let provider = session.begin(moving.id, order: [moving.id, project.id, child.id])
    defer { withExtendedLifetime(provider) {} }
    session.previewEnd(listID: destination, visibleTasks: [project, child], allTasks: [moving, project, child])
    try await Task.sleep(for: .milliseconds(160))
    XCTAssertEqual(session.placement?.parentID, nil)
    XCTAssertEqual(session.placement?.listID, destination)
    XCTAssertEqual(session.order, [project.id, child.id, moving.id])
    let emptyList = UUID()
    session.previewEnd(listID: emptyList, visibleTasks: [], allTasks: [moving, project, child])
    try await Task.sleep(for: .milliseconds(160))
    XCTAssertEqual(session.placement?.listID, emptyList)
    XCTAssertEqual(session.placement?.target, moving.id)
    XCTAssertEqual(session.order, [project.id, child.id, moving.id])
    session.reset(animated: false)
  }

  @MainActor
  func testPreviewMovesIntoProjectThenBackBetweenRoots() async throws {
    let session = BoardReorderSession(kind: .task)
    let source = UUID(), project = UUID(), child = UUID(), sibling = UUID()
    let provider = session.begin(source, order: [source, project, child, sibling])
    defer { withExtendedLifetime(provider) {} }
    let nested = BoardReorderSession.Placement(parentID: project, listID: nil, target: child, after: false)
    session.preview(nested)
    XCTAssertNil(session.placement)
    try await Task.sleep(for: .milliseconds(320))
    XCTAssertEqual(session.placement, nested)
    XCTAssertEqual(session.order, [project, source, child, sibling])
    let extracted = BoardReorderSession.Placement(parentID: nil, listID: nil, target: sibling, after: true)
    session.preview(extracted)
    try await Task.sleep(for: .milliseconds(320))
    XCTAssertEqual(session.placement, extracted)
    XCTAssertEqual(session.order, [project, child, sibling, source])
    session.reset(animated: false)
    XCTAssertNil(session.placement)
    XCTAssertNil(session.source)
  }

  @MainActor
  func testLeavingTargetCancelsPendingInsertion() async throws {
    let session = BoardReorderSession(kind: .task)
    let source = UUID(), target = UUID()
    let provider = session.begin(source, order: [source, target])
    defer { withExtendedLifetime(provider) {} }
    session.preview(.init(parentID: target, listID: nil, target: target, after: true))
    session.cancelHover()
    try await Task.sleep(for: .milliseconds(320))
    XCTAssertNil(session.placement)
    XCTAssertEqual(session.order, [source, target])
  }
}
