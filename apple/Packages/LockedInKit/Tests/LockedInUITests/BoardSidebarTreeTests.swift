import LockedInDomain
import XCTest
@testable import LockedInUI

final class BoardSidebarTreeTests: XCTestCase {
  func testCollapsingBranchKeepsParentAndOtherRootsVisible() {
    let general = BoardRecord(input: BoardInput(name: "General"), code: "general")
    let study = BoardRecord(input: BoardInput(name: "Study", parentID: general.id))
    let math = BoardRecord(input: BoardInput(name: "Math", parentID: study.id))
    let algebra = BoardRecord(input: BoardInput(name: "Algebra", parentID: math.id))
    let work = BoardRecord(input: BoardInput(name: "Work"))
    let tree = BoardSidebarTree(boards: [general, study, math, algebra, work])
    XCTAssertEqual(tree.entries(collapsed: []).map(\.id), [study.id, math.id, algebra.id, work.id])
    XCTAssertEqual(tree.entries(collapsed: []).map(\.depth), [0, 1, 2, 0])
    XCTAssertEqual(tree.entries(collapsed: [study.id]).map(\.id), [study.id, work.id])
    XCTAssertEqual(tree.entries(collapsed: [math.id]).map(\.id), [study.id, math.id, work.id])
    XCTAssertEqual(tree.entries(collapsed: []).map(\.hasChildren), [true, true, false, false])
    XCTAssertEqual(tree.ancestors(of: algebra.id), [general.id, study.id, math.id])
  }

  func testSubjectBoardRequiresBothParentAndSubjectTagsAndKeepsLists() {
    let studyTag = TagRecord(name: "Study", color: "#6558E8")
    let mathTag = TagRecord(name: "Math", color: "#6558E8")
    let general = BoardRecord(input: BoardInput(name: "General"), code: "general")
    let study = BoardRecord(input: BoardInput(name: "Study", parentID: general.id, tagIDs: [studyTag.id]))
    let math = BoardRecord(input: BoardInput(name: "Math", parentID: study.id, tagIDs: [mathTag.id]))
    let list = TaskList(input: ListInput(name: "Next", boardID: general.id))
    let homework = TaskRecord(input: TaskInput(title: "Homework", listID: list.id, tagIDs: [studyTag.id, mathTag.id]))
    let otherSubject = TaskRecord(input: TaskInput(title: "Other", listID: list.id, tagIDs: [studyTag.id]))
    let outsideStudy = TaskRecord(input: TaskInput(title: "Outside", listID: list.id, tagIDs: [mathTag.id]))
    let snapshot = Snapshot(tasks: [homework, otherSubject, outsideStudy], boards: [general, study, math], lists: [list])
    XCTAssertEqual(TrackerRules.tasks(on: math.id, snapshot: snapshot).map(\.id), [homework.id])
    XCTAssertEqual(TrackerRules.lists(in: math.id, snapshot: snapshot).map(\.id), [list.id])
  }
  func testSavedOrderMovesWholeBranchesAndKeepsCollapsedChildren() {
    let general = BoardRecord(input: BoardInput(name: "General"), code: "general")
    let study = BoardRecord(input: BoardInput(name: "Study", parentID: general.id))
    let math = BoardRecord(input: BoardInput(name: "Math", parentID: study.id))
    let work = BoardRecord(input: BoardInput(name: "Work"))
    let tree = BoardSidebarTree(boards: [general, study, math, work], order: [work.id, math.id, study.id])
    XCTAssertEqual(tree.entries(collapsed: []).map(\.id), [work.id, study.id, math.id])
    XCTAssertEqual(tree.entries(collapsed: []).map(\.depth), [0, 0, 1])
    XCTAssertEqual(tree.entries(collapsed: [study.id]).map(\.id), [work.id, study.id])
  }
  func testDropResolvesBranchAndRejectsChangingParent() {
    let general = BoardRecord(input: BoardInput(name: "General"), code: "general")
    let study = BoardRecord(input: BoardInput(name: "Study", parentID: general.id))
    let math = BoardRecord(input: BoardInput(name: "Math", parentID: study.id))
    let algebra = BoardRecord(input: BoardInput(name: "Algebra", parentID: math.id))
    let physics = BoardRecord(input: BoardInput(name: "Physics", parentID: study.id))
    let work = BoardRecord(input: BoardInput(name: "Work"))
    let tree = BoardSidebarTree(boards: [general, study, math, algebra, physics, work])
    XCTAssertEqual(tree.reorderTarget(source: work.id, hovered: algebra.id), study.id)
    XCTAssertEqual(tree.reorderTarget(source: math.id, hovered: physics.id), physics.id)
    XCTAssertEqual(tree.reorderTarget(source: math.id, hovered: algebra.id), math.id)
    XCTAssertNil(tree.reorderTarget(source: math.id, hovered: work.id))
    XCTAssertNil(tree.reorderTarget(source: study.id, hovered: general.id))
  }

  func testRowEdgeUsesExplicitInsertionAndRepeatedDropIsStable() async {
    await MainActor.run {
      let a = BoardRecord(input: BoardInput(name: "A"))
      let b = BoardRecord(input: BoardInput(name: "B"))
      let c = BoardRecord(input: BoardInput(name: "C"))
      let tree = BoardSidebarTree(boards: [a, b, c], order: [a.id, b.id, c.id])
      let session = SidebarBoardDragSession()
      let provider = session.begin(c.id, order: tree.order)
      let gap = session.placement(on: b.id, y: 0, height: 28, tree: tree)
      XCTAssertEqual(gap, SidebarBoardPlacement(target: b.id, after: false))
      if let gap {
        let result = session.commit(gap)
        XCTAssertEqual(result, [a.id, c.id, b.id])
        XCTAssertEqual(session.commit(gap), result)
      }
      XCTAssertNil(session.placement(on: UUID(), y: 0, height: 28, tree: tree))
      withExtendedLifetime(provider) {}
    }
  }
  func testChildCanDropAfterLastSiblingWithoutChangingParent() async {
    await MainActor.run {
      let parent = BoardRecord(input: BoardInput(name: "Parent"))
      let a = BoardRecord(input: BoardInput(name: "A", parentID: parent.id))
      let b = BoardRecord(input: BoardInput(name: "B", parentID: parent.id))
      let other = BoardRecord(input: BoardInput(name: "Other"))
      let tree = BoardSidebarTree(boards: [parent, a, b, other], order: [parent.id, a.id, b.id, other.id])
      let session = SidebarBoardDragSession()
      let provider = session.begin(a.id, order: tree.order)
      let gap = session.placement(on: b.id, y: 28, height: 28, tree: tree)
      XCTAssertEqual(gap, SidebarBoardPlacement(target: b.id, after: true))
      if let gap {
        let reordered = BoardSidebarTree(boards: tree.boards, order: session.commit(gap))
        XCTAssertEqual(reordered.entries(collapsed: []).map(\.id), [parent.id, b.id, a.id, other.id])
      }
      withExtendedLifetime(provider) {}
    }
  }

}
