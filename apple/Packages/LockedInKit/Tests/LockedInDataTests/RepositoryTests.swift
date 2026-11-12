import LockedInDomain
import XCTest

@testable import LockedInData

final class RepositoryTests: XCTestCase {
    func testLocalDataSurvivesNewRepositoryAndFailedDeleteDoesNotCorruptIt() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("tasks.json")
        let first = LocalRepository(file: file)
        let tag: TagRecord
        guard case .tag(let value) = try await first.apply(.tag(nil, name: "backend", color: "#6558E8")) else {
            return XCTFail("No tag")
        }
        tag = value
        let root: TaskList
        guard case .list(let value) = try await first.apply(.list(nil, ListInput(name: "Работа"))) else {
            return XCTFail("No list")
        }
        root = value
        let task: TaskRecord
        guard
            case .task(let value) = try await first.apply(
                .task(nil, TaskInput(title: "API", listID: root.id, durationMinutes: 60, tagIDs: [tag.id])))
        else { return XCTFail("No task") }
        task = value
        do {
            _ = try await first.apply(.deleteTag(tag.id))
            XCTFail("Used tag deleted")
        } catch {}
        _ = try await first.apply(.completed(task.id, true))
        _ = try await first.apply(.comment(nil, taskID: task.id, text: "Заметка"))
        let second = LocalRepository(file: file)
        let restored = try await second.load()
        XCTAssertEqual(restored.tasks.count, 1)
        XCTAssertTrue(restored.tasks[0].completed)
        XCTAssertNil(restored.tasks[0].plannedAt)
        XCTAssertEqual(restored.comments.count, 1)
        _ = try await second.apply(.deleteTask(task.id))
        let third = try await LocalRepository(file: file).load()
        XCTAssertTrue(third.tasks.isEmpty)
        XCTAssertTrue(third.comments.isEmpty)
    }
    func testCorruptedFileIsNeverOverwritten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("tasks.json")
        let original = Data("broken snapshot".utf8)
        try original.write(to: file)
        do {
            _ = try await LocalRepository(file: file).load()
            XCTFail("Corrupted data accepted")
        } catch {}
        XCTAssertEqual(try Data(contentsOf: file), original)
    }
    func testServerCRUDAndNullablePatchAgainstRunningBackend() async throws {
        guard let address = ProcessInfo.processInfo.environment["LOCKED_IN_TEST_SERVER"], let url = URL(string: address)
        else { throw XCTSkip("Dedicated test backend required") }
        let repository = HTTPRepository(baseURL: url)
        let snapshot = try await repository.load()
        guard snapshot.user.username == "apple_mvp_test" else {
            XCTFail("Refusing to modify a non-test backend")
            return
        }
        guard
            case .list(let root) = try await repository.apply(
                .list(nil, ListInput(name: "Swift test " + UUID().uuidString)))
        else { return XCTFail("No list") }
        guard
            case .tag(let tag) = try await repository.apply(
                .tag(nil, name: "Swift tag " + UUID().uuidString, color: "#6558E8"))
        else { return XCTFail("No tag") }
        guard
            case .task(let task) = try await repository.apply(
                .task(
                    nil,
                    TaskInput(
                        title: "From Swift", listID: root.id, deadlineDate: "2026-11-20", durationMinutes: 45,
                        tagIDs: [tag.id])))
        else { return XCTFail("No task") }
        var input = TaskInput(task)
        input.deadlineDate = nil
        input.plannedAt = .now
        input.listID = nil
        input.tagIDs = []
        guard case .task(let updated) = try await repository.apply(.task(task.id, input)) else {
            return XCTFail("No update")
        }
        XCTAssertNil(updated.deadlineDate)
        XCTAssertNil(updated.listID)
        XCTAssertTrue(updated.tagIDs.isEmpty)
        XCTAssertNotNil(updated.plannedAt)
        guard
            case .comment(let comment) = try await repository.apply(.comment(nil, taskID: task.id, text: "Комментарий"))
        else { return XCTFail("No comment") }
        _ = try await repository.apply(.completed(task.id, true))
        let loaded = try await repository.load()
        XCTAssertTrue(loaded.tasks.first { $0.id == task.id }!.completed)
        _ = try await repository.apply(.deleteComment(comment.id))
        _ = try await repository.apply(.deleteTask(task.id))
        _ = try await repository.apply(.deleteTag(tag.id))
        _ = try await repository.apply(.deleteList(root.id))
    }
    func testBoardCRUDThroughAPI() async throws {
        guard let address = ProcessInfo.processInfo.environment["LOCKED_IN_TEST_SERVER"], let url = URL(string: address)
        else { throw XCTSkip("Dedicated test backend required") }
        let repository = HTTPRepository(baseURL: url)
        guard try await repository.load().user.username == "apple_mvp_test" else {
            XCTFail("Refusing non-test backend")
            return
        }
        guard
            case .board(let parent) = try await repository.apply(
                .board(nil, BoardInput(name: "Swift board " + UUID().uuidString)))
        else { return XCTFail() }
        guard
            case .list(let first) = try await repository.apply(
                .list(nil, ListInput(name: "Первый", boardID: parent.id)))
        else { return XCTFail() }
        guard
            case .list(let second) = try await repository.apply(
                .list(nil, ListInput(name: "Второй", boardID: parent.id)))
        else { return XCTFail() }
        guard case .tag(let tag) = try await repository.apply(.tag(nil, name: "Board filter", color: "#6558E8")) else {
            return XCTFail()
        }
        guard
            case .board(let child) = try await repository.apply(
                .board(nil, BoardInput(name: "Swift filtered", parentID: parent.id, tagIDs: [tag.id])))
        else { return XCTFail() }
        guard
            case .task(let task) = try await repository.apply(
                .task(nil, TaskInput(title: "Второй список", listID: second.id, tagIDs: [tag.id])))
        else { return XCTFail() }
        let snapshot = try await repository.load()
        XCTAssertEqual(TrackerRules.lists(in: child.id, snapshot: snapshot).map(\.id), [first.id, second.id])
        XCTAssertEqual(TrackerRules.tasks(on: child.id, snapshot: snapshot).map(\.id), [task.id])
        _ = try await repository.apply(.deleteTask(task.id))
        _ = try await repository.apply(.deleteBoard(child.id))
        _ = try await repository.apply(.deleteTag(tag.id))
        _ = try await repository.apply(.deleteList(first.id))
        _ = try await repository.apply(.deleteList(second.id))
        _ = try await repository.apply(.deleteBoard(parent.id))
    }

}
