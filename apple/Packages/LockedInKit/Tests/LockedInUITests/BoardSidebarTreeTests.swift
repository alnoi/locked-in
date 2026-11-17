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
}
