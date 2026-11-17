import Foundation
import LockedInDomain
import XCTest
@testable import LockedInUI

final class TaskEditorChangesTests: XCTestCase {
  func testOpeningEditorDoesNotCountDefaultsAndURLFormattingAsChanges() throws {
    let original = TaskInput(title: "Task", description: "Old note\nhttps://example.com")
    var draft = original
    draft.description = try TaskLinks(stored: original.description).stored()
    draft.reminderMode = ReminderMode.none
    draft.reminderMinutesBefore = 0
    XCTAssertFalse(try TaskEditorChanges.hasChanges(draft, from: original))
  }

  func testChangedTaskFieldsRequireSaving() throws {
    let original = TaskInput(title: "Task")
    let changes: [(inout TaskInput) -> Void] = [
      { $0.title = "Edited" },
      { $0.plannedAt = Date(timeIntervalSince1970: 2000) },
      { $0.durationMinutes = 45 },
      { $0.deadlineDate = "2026-11-20" },
      { $0.tagIDs = [UUID()] },
      { $0.listID = UUID() },
      { $0.description = "https://example.com" },
      { $0.reminderMode = .notification },
    ]
    for change in changes {
      var draft = original
      change(&draft)
      XCTAssertTrue(try TaskEditorChanges.hasChanges(draft, from: original))
    }
  }
}
