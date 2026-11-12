#if os(iOS)
  import ActivityKit
  import LockedInActivity
  import LockedInDomain
  import UIKit

  @MainActor
  final class TaskLiveActivityManager {
    func reconcile(_ tasks: [TaskRecord], tags: [TagRecord], space: String) async throws {
      guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
      let now = Date.now
      let next = tasks.filter { !$0.completed && ($0.reminderMode ?? .none) != .none }
        .compactMap { task -> (TaskRecord, Date)? in
          guard let date = task.plannedAt ?? task.deadlineAt,
            date > now.addingTimeInterval(-300), date < now.addingTimeInterval(8 * 3600)
          else { return nil }
          return (task, date)
        }.min { $0.1 < $1.1 }
      let activities = Activity<TaskActivityAttributes>.activities
      for activity in activities
      where activity.attributes.space != space || activity.attributes.taskID != next?.0.id {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      guard let (task, date) = next else { return }
      let selected = tags.filter { task.tagIDs.contains($0.id) }
      let state = TaskActivityAttributes.ContentState(
        title: task.title, eventDate: date, tagNames: selected.map(\.name),
        colorHex: selected.first?.color ?? "#A398FF")
      let content = ActivityContent(state: state, staleDate: date, relevanceScore: 1)
      if let current = activities.first(where: {
        $0.attributes.space == space && $0.attributes.taskID == task.id
      }) {
        if current.content.state != state { await current.update(content) }
      } else if UIApplication.shared.applicationState == .active {
        _ = try Activity.request(
          attributes: TaskActivityAttributes(taskID: task.id, space: space), content: content,
          pushType: nil)
      }
    }
  }
#endif
