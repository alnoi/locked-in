import LockedInDomain
import XCTest

@testable import LockedInData

final class ListOrderingTests: XCTestCase {
  func testPreferencesSurviveReopenRefreshAndAreInherited() throws {
    let suite = "ListOrderTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let user = UserRecord()
    let parent = BoardRecord(input: BoardInput(name: "Parent"))
    let child = BoardRecord(input: BoardInput(name: "Child", parentID: parent.id))
    let a = TaskList(input: ListInput(name: "A", boardID: parent.id), position: 0)
    let b = TaskList(input: ListInput(name: "B", boardID: parent.id), position: 1)
    let c = TaskList(input: ListInput(name: "C", boardID: parent.id), position: 2)
    let reordered = try ListOrdering.move(c.id, before: a.id, lists: [a, b, c])
    ListOrderPreferences.save(reordered, space: "server", userID: user.id, defaults: defaults)
    var refreshed = Snapshot(user: user, boards: [parent, child], lists: [a, b, c])
    ListOrderPreferences.apply(
      to: &refreshed, space: "server", defaults: UserDefaults(suiteName: suite)!)
    XCTAssertEqual(
      TrackerRules.lists(in: parent.id, snapshot: refreshed).map(\.name), ["C", "A", "B"])
    XCTAssertEqual(
      TrackerRules.lists(in: child.id, snapshot: refreshed).map(\.name), ["C", "A", "B"])
    let d = TaskList(input: ListInput(name: "D", boardID: parent.id))
    refreshed.lists = [a, b, c, d]
    ListOrderPreferences.apply(to: &refreshed, space: "server", defaults: defaults)
    XCTAssertEqual(refreshed.rootLists.map(\.name), ["C", "A", "B", "D"])
    var other = Snapshot(user: user, boards: [parent], lists: [a, b, c])
    ListOrderPreferences.apply(to: &other, space: "local", defaults: defaults)
    XCTAssertEqual(other.rootLists.map(\.name), ["A", "B", "C"])
  }
  func testInboxPositionSurvivesReopenAndRefresh() {
    let suite = "InboxOrderTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let user = UserRecord()
    let a = TaskList(input: ListInput(name: "A"), position: 0)
    let b = TaskList(input: ListInput(name: "B"), position: 1)
    XCTAssertEqual(
      ListOrderPreferences.orderedIDs(
        [a, b], space: "server", userID: user.id, defaults: defaults),
      [ListOrdering.inboxID, a.id, b.id])
    let order = [b.id, ListOrdering.inboxID, a.id]
    ListOrderPreferences.saveIDs(order, space: "server", userID: user.id, defaults: defaults)
    var refreshed = Snapshot(user: user, lists: [a, b])
    let reopened = UserDefaults(suiteName: suite)!
    ListOrderPreferences.apply(to: &refreshed, space: "server", defaults: reopened)
    XCTAssertEqual(
      ListOrderPreferences.orderedIDs(
        refreshed.lists, space: "server", userID: user.id, defaults: reopened), order)
    XCTAssertEqual(refreshed.rootLists.map(\.id), [b.id, a.id])
    XCTAssertEqual(
      BoardDragPayload(text: BoardDragPayload.list(ListOrdering.inboxID).text),
      .list(ListOrdering.inboxID))
  }
  func testHoverPreviewMakesRoomWithoutChangingSavedOrder() {
    let a = UUID()
    let b = UUID()
    let c = UUID()
    let original = [ListOrdering.inboxID, a, b, c]
    let preview = ListOrdering.preview(moving: ListOrdering.inboxID, over: b, ids: original)
    XCTAssertEqual(preview, [a, b, ListOrdering.inboxID, c])
    XCTAssertEqual(original, [ListOrdering.inboxID, a, b, c])
    XCTAssertEqual(
      ListOrdering.preview(moving: ListOrdering.inboxID, over: ListOrdering.inboxID, ids: preview),
      preview)
    XCTAssertEqual(
      ListOrdering.preview(moving: ListOrdering.inboxID, over: a, ids: preview), original)
    XCTAssertEqual(ListOrdering.preview(moving: UUID(), over: a, ids: preview), preview)
  }
  func testDropDirectionAndPayloads() throws {
    let a = TaskList(input: ListInput(name: "A"), position: 0)
    let b = TaskList(input: ListInput(name: "B"), position: 1)
    let c = TaskList(input: ListInput(name: "C"), position: 2)
    let before = ListOrdering.targetBefore(moving: a.id, over: b.id, visible: [a, b, c])
    XCTAssertEqual(
      try ListOrdering.move(a.id, before: before, lists: [a, b, c]).map(\.name), ["B", "A", "C"])
    XCTAssertEqual(BoardDragPayload(text: BoardDragPayload.list(a.id).text), .list(a.id))
    XCTAssertEqual(BoardDragPayload(text: a.id.uuidString), .task(a.id))
    XCTAssertNil(BoardDragPayload(text: "random text"))
  }
  func testOldListWithoutPositionDecodes() throws {
    let id = UUID()
    let data = Data(
      "{\"id\":\"\(id)\",\"name\":\"Old\",\"createdAt\":\"2026-11-11T00:00:00Z\",\"updatedAt\":\"2026-11-11T00:00:00Z\"}"
        .utf8)
    let list = try JSONCodec.decoder().decode(TaskList.self, from: data)
    XCTAssertEqual(list.id, id)
    XCTAssertEqual(list.position, 0)
  }
}
