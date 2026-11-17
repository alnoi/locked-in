import Foundation
import LockedInDomain
import Observation

@MainActor @Observable
final class DayProgressState {
  private(set) var unreadOverdueCount = 0
  var celebrationID: UUID?
  private var space = ""
  private var preferenceKey = ""
  private var seen: [String: String] = [:]
  private var overdue: [String: String] = [:]
  private var overdueVisible = false
  private var observedDay = ""
  private var incompleteToday = Set<UUID>()

  func update(tasks: [TaskRecord], space: String, now: Date = .now) {
    if self.space != space {
      self.space = space
      preferenceKey = "trackit.dayProgress." + Data(space.utf8).base64EncodedString()
      seen = UserDefaults.standard.dictionary(forKey: preferenceKey + ".seen") as? [String: String] ?? [:]
      observedDay = ""
      incompleteToday = []
      celebrationID = nil
    }
    let values = tasks.filter { WidgetAgenda.needsRescheduling($0, now: now) }
    overdue = Dictionary(uniqueKeysWithValues: values.map { task in
      let event: String
      if WidgetAgenda.isOverdue(task, now: now) {
        event = "deadline:" + (task.deadlineAt.map { String($0.timeIntervalSince1970) } ?? task.deadlineDate ?? "")
      } else {
        event = "plan:" + (task.plannedAt.map { String($0.timeIntervalSince1970) } ?? "")
      }
      return (task.id.uuidString, event)
    })
    let previousSeen = seen
    seen = seen.filter { overdue[$0.key] == $0.value }
    if overdueVisible { seen = overdue }
    unreadOverdueCount = overdue.filter { seen[$0.key] != $0.value }.count
    if seen != previousSeen { UserDefaults.standard.set(seen, forKey: preferenceKey + ".seen") }

    let today = WidgetAgenda.dayKey(now)
    let planned = DayPlan.tasks(tasks, on: now)
    let newlyCompleted = planned.contains { $0.completed && incompleteToday.contains($0.id) }
    if observedDay == today, !planned.isEmpty, planned.allSatisfy(\.completed), newlyCompleted,
      UserDefaults.standard.string(forKey: preferenceKey + ".celebrated") != today {
      celebrationID = UUID()
      UserDefaults.standard.set(today, forKey: preferenceKey + ".celebrated")
    }
    observedDay = today
    incompleteToday = Set(planned.filter { !$0.completed }.map(\.id))
  }
  func setOverdueVisible(_ visible: Bool) {
    overdueVisible = visible
    guard visible, !preferenceKey.isEmpty else { return }
    seen = overdue
    unreadOverdueCount = 0
    UserDefaults.standard.set(seen, forKey: preferenceKey + ".seen")
  }
}
