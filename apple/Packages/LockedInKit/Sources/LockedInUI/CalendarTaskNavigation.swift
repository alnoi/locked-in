import Foundation
import LockedInDomain

struct CalendarTaskFocus: Equatable {
  let id = UUID()
  let taskID: UUID?
  let date: Date
  init(taskID: UUID? = nil, date: Date) { self.taskID = taskID; self.date = date }
}

enum CalendarTaskNavigation {
  static func unschedule(_ task: TaskRecord) -> TaskInput {
    var input = TaskInput(task)
    input.plannedAt = nil
    return input
  }

  static func planIfNeeded(_ task: TaskRecord, now: Date) -> TaskInput? {
    guard task.plannedAt == nil else { return nil }
    var input = TaskInput(task)
    input.plannedAt = now
    input.durationMinutes = 60
    return input
  }
}
