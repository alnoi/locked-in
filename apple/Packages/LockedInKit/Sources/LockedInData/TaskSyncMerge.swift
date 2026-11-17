import Foundation
import LockedInDomain

enum TaskSyncMerge {
  static func merging(local: TaskRecord, base: TaskRecord?, remote: TaskRecord?) -> TaskRecord {
    guard let base, let remote else { return local }
    var result = local
    func preserve<T: Equatable>(_ key: WritableKeyPath<TaskRecord, T>) {
      if local[keyPath: key] == base[keyPath: key] { result[keyPath: key] = remote[keyPath: key] }
    }
    preserve(\.title)
    preserve(\.description)
    preserve(\.listID)
    preserve(\.parentID)
    preserve(\.isProject)
    preserve(\.deadlineDate)
    preserve(\.deadlineAt)
    preserve(\.plannedAt)
    preserve(\.durationMinutes)
    preserve(\.reminderMode)
    preserve(\.reminderMinutesBefore)
    preserve(\.tagIDs)
    preserve(\.completed)
    result.createdAt = remote.createdAt
    return result
  }
}
