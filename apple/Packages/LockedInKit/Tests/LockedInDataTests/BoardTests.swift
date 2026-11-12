import LockedInDomain
import XCTest

@testable import LockedInData

final class BoardTests: XCTestCase {
    func testViewPreferenceIsPerBoardAndSpace() throws {
        let suite = "LockedInTests." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let general = UUID()
        let other = UUID()
        XCTAssertEqual(
            BoardPreferences.style(boardID: general, isGeneral: true, space: "local", defaults: defaults), .columns)
        XCTAssertEqual(
            BoardPreferences.style(boardID: other, isGeneral: false, space: "local", defaults: defaults), .rows)
        BoardPreferences.save(.columns, boardID: other, space: "local", defaults: defaults)
        let reopened = UserDefaults(suiteName: suite)!
        XCTAssertEqual(
            BoardPreferences.style(boardID: other, isGeneral: false, space: "local", defaults: reopened), .columns)
        XCTAssertEqual(
            BoardPreferences.style(boardID: other, isGeneral: false, space: "server", defaults: reopened), .rows)
    }
    func testLegacyArchiveMigratesWithoutLosingTasksAndKeepsBackup() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let user = UserRecord()
        let listID = UUID()
        let childID = UUID()
        let taskID = UUID()
        let tagID = UUID()
        let stamp = "2026-11-11T00:00:00Z"
        let snapshot: [String: Any] = [
            "user": ["id": user.id.uuidString, "username": "local", "timeZone": "UTC", "createdAt": stamp],
            "lists": [
                ["id": listID.uuidString, "name": "Работа", "tagIDs": [], "createdAt": stamp, "updatedAt": stamp],
                [
                    "id": childID.uuidString, "name": "Фокус", "parentID": listID.uuidString,
                    "tagIDs": [tagID.uuidString], "createdAt": stamp, "updatedAt": stamp,
                ],
            ],
            "tasks": [
                [
                    "id": taskID.uuidString, "title": "Сохранить", "listID": listID.uuidString,
                    "tagIDs": [tagID.uuidString], "completed": false, "createdAt": stamp, "updatedAt": stamp,
                ]
            ],
            "tags": [["id": tagID.uuidString, "name": "фокус", "createdAt": stamp, "updatedAt": stamp]], "comments": [],
        ]
        let raw = try JSONSerialization.data(withJSONObject: [
            "snapshot": snapshot, "deletedTasks": [], "deletedLists": [], "deletedTags": [], "deletedComments": [],
        ])
        let file = directory.appendingPathComponent("local.json")
        try raw.write(to: file)
        let migrated = try await LocalRepository(file: file).load()
        XCTAssertEqual(migrated.lists.count, 1)
        XCTAssertEqual(migrated.tasks.map(\.id), [taskID])
        XCTAssertEqual(migrated.boards.count, 2)
        XCTAssertEqual(TrackerRules.tasks(on: childID, snapshot: migrated).map(\.id), [taskID])
        XCTAssertEqual(try Data(contentsOf: file.appendingPathExtension("before_boards")), raw)
        let again = try await LocalRepository(file: file).load()
        XCTAssertEqual(again.boards.map(\.id), migrated.boards.map(\.id))
    }
}
