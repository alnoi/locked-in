import XCTest

@testable import LockedInDomain

final class RulesTests: XCTestCase {
    func testChildBoardPreservesEveryListAndFiltersOnlyTasks() throws {
        let tag = TagRecord(name: "backend", color: "#6558E8")
        let parent = BoardRecord(input: BoardInput(name: "Работа"))
        let child = BoardRecord(
            input: BoardInput(name: "Backend", parentID: parent.id, filterCompleted: false, tagIDs: [tag.id]))
        let first = TaskList(input: ListInput(name: "Первый", boardID: parent.id),position:0)
        let second = TaskList(input: ListInput(name: "Второй", boardID: parent.id),position:1)
        let a = TaskRecord(input: TaskInput(title: "А", listID: first.id, tagIDs: [tag.id]))
        let b = TaskRecord(input: TaskInput(title: "Б", listID: second.id, tagIDs: [tag.id]))
        let hidden = TaskRecord(input: TaskInput(title: "Без тега", listID: first.id))
        let done = TaskRecord(
            input: TaskInput(title: "Завершено", listID: second.id, tagIDs: [tag.id]), completed: true)
        let snapshot = Snapshot(
            tasks: [a, b, hidden, done], boards: [parent, child], lists: [first, second], tags: [tag])
        XCTAssertEqual(TrackerRules.lists(in: child.id, snapshot: snapshot).map(\.id), [first.id, second.id])
        XCTAssertEqual(Set(TrackerRules.tasks(on: child.id, snapshot: snapshot).map(\.id)), Set([a.id, b.id]))
        XCTAssertEqual(TrackerRules.tasks(in: first.id, snapshot: snapshot).count, 2)
        let grandchild = BoardRecord(input: BoardInput(name: "Противоречие", parentID: child.id, filterCompleted: true))
        var changed = snapshot
        changed.boards.append(grandchild)
        XCTAssertTrue(TrackerRules.tasks(on: grandchild.id, snapshot: changed).isEmpty)
        XCTAssertEqual(TrackerRules.lists(in: grandchild.id, snapshot: changed).count, 2)
    }
    func testGeneralBoardAggregatesListsAndInbox() throws {
        let general = BoardRecord(input: BoardInput(name: "Общая"), code: "general")
        let personal = BoardRecord(input: BoardInput(name: "Личное"))
        let list = TaskList(input: ListInput(name: "Дом", boardID: personal.id))
        let task = TaskRecord(input: TaskInput(title: "А", listID: list.id))
        let inbox = TaskRecord(input: TaskInput(title: "Мысль"))
        let snapshot = Snapshot(tasks: [task, inbox], boards: [general, personal], lists: [list])
        XCTAssertEqual(TrackerRules.tasks(on: general.id, snapshot: snapshot).count, 2)
        XCTAssertEqual(TrackerRules.tasks(on: personal.id, snapshot: snapshot).count, 1)
        XCTAssertEqual(TrackerRules.lists(in: general.id, snapshot: snapshot).map(\.id), [list.id])
    }
    func testDepthAndCyclesAreRejected() throws {
        let parent = TaskRecord(input: TaskInput(title: "Проект"))
        let child = TaskRecord(input: TaskInput(title: "Шаг", parentID: parent.id))
        let snapshot = Snapshot(tasks: [parent, child])
        XCTAssertThrowsError(
            try TrackerRules.validate(TaskInput(title: "Третий", parentID: child.id), id: nil, in: snapshot))
        let root = BoardRecord(input: BoardInput(name: "Root"))
        let filtered = BoardRecord(input: BoardInput(name: "Child", parentID: root.id))
        XCTAssertThrowsError(
            try TrackerRules.validate(
                BoardInput(name: "Cycle", parentID: filtered.id), id: root.id, in: Snapshot(boards: [root, filtered])))
        XCTAssertThrowsError(
            try TrackerRules.validate(
                ListInput(name: "Нельзя", boardID: filtered.id), id: nil, in: Snapshot(boards: [root, filtered])))
    }
    func testCalendarClipsMidnightAndSeparatesOverlaps() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let start = ISO8601DateFormatter().date(from: "2026-11-11T00:00:00Z")!
        let overnight = TaskRecord(
            input: TaskInput(title: "Ночь", plannedAt: start.addingTimeInterval(-1800), durationMinutes: 90))
        let overlap = TaskRecord(
            input: TaskInput(title: "Рядом", plannedAt: start.addingTimeInterval(1800), durationMinutes: 60))
        let point = TaskRecord(input: TaskInput(title: "Точка", plannedAt: start))
        XCTAssertTrue(TrackerRules.overlaps(point, from: start, to: start.addingTimeInterval(86400)))
        let placements = TimelineLayout.placements(tasks: [overnight, overlap], day: start, calendar: calendar)
        XCTAssertEqual(placements.count, 2)
        XCTAssertEqual(placements[0].startMinute, 0)
        XCTAssertEqual(placements[0].durationMinutes, 60)
        XCTAssertEqual(Set(placements.map(\.columns)), [2])
        XCTAssertEqual(Set(placements.map(\.column)), [0, 1])
    }
    func testOnlyTitleIsRequired() throws {
        XCTAssertNoThrow(try TrackerRules.validate(TaskInput(title: "Мысль"), id: nil, in: Snapshot()))
        XCTAssertNoThrow(
            try TrackerRules.validate(TaskInput(title: "Оценка", durationMinutes: 45), id: nil, in: Snapshot()))
        XCTAssertThrowsError(
            try TrackerRules.validate(TaskInput(title: "Bad", deadlineDate: "2026-02-30"), id: nil, in: Snapshot()))
    }
}
