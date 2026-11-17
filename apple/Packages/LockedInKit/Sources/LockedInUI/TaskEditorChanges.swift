import Foundation
import LockedInDomain

enum TaskEditorChanges {
  static func hasChanges(_ draft: TaskInput, from original: TaskInput) throws -> Bool {
    try normalized(draft) != normalized(original)
  }

  private static func normalized(_ input: TaskInput) throws -> TaskInput {
    var value = input
    value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
    value.description = try TaskLinks(stored: value.description).stored()
    value.reminderMode = value.reminderMode ?? ReminderMode.none
    value.reminderMinutesBefore = value.reminderMinutesBefore ?? 0
    return value
  }
}
