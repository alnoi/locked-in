import Foundation
import LockedInDomain
import XCTest
@testable import LockedInData

final class BoardOrderPreferencesTests: XCTestCase {
  func testOrderPersistsAndIsIsolatedByAccountAndSource() {
    let suite = "BoardOrderTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let user = UUID()
    let general = BoardRecord(input: BoardInput(name: "General"), code: "general")
    let a = BoardRecord(input: BoardInput(name: "A"), createdAt: Date(timeIntervalSince1970: 1))
    let b = BoardRecord(input: BoardInput(name: "B"), createdAt: Date(timeIntervalSince1970: 2))
    let c = BoardRecord(input: BoardInput(name: "C"), createdAt: Date(timeIntervalSince1970: 3))
    BoardOrderPreferences.save([b.id, a.id], space: "server", userID: user, defaults: defaults)
    let reopened = UserDefaults(suiteName: suite)!
    XCTAssertEqual(BoardOrderPreferences.orderedIDs([general, a, b, c], space: "server", userID: user, defaults: reopened), [b.id, a.id, c.id])
    XCTAssertEqual(BoardOrderPreferences.orderedIDs([general, b, c], space: "server", userID: user, defaults: reopened), [b.id, c.id])
    XCTAssertEqual(BoardOrderPreferences.orderedIDs([a, b], space: "server", userID: UUID(), defaults: reopened), [a.id, b.id])
    XCTAssertEqual(BoardOrderPreferences.orderedIDs([a, b], space: "local", userID: user, defaults: reopened), [a.id, b.id])
  }
}
