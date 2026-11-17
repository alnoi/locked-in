import Foundation

public enum DayPlan {
  public static func tasks(_ tasks: [TaskRecord], on day: Date = .now, calendar: Calendar = .current) -> [TaskRecord] {
    tasks.filter { task in task.plannedAt.map { calendar.isDate($0, inSameDayAs: day) } == true }
  }
}
