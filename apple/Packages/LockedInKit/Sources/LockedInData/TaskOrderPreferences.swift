import Foundation
import LockedInDomain

public enum TaskOrderPreferences {
  public static func orderedIDs(
    _ tasks: [TaskRecord], space: String, userID: UUID, defaults: UserDefaults = .standard
  ) -> [UUID] {
    let stored = defaults.stringArray(forKey: key(space, userID))?.compactMap(UUID.init(uuidString:)) ?? []
    return TaskOrdering.orderedIDs(tasks, stored: stored)
  }
  public static func merging(_ visible: [UUID], into current: [UUID]) -> [UUID] {
    TaskOrdering.merging(visible, into: current)
  }
  public static func hasSavedOrder(space: String, userID: UUID, defaults: UserDefaults = .standard) -> Bool {
    !(defaults.stringArray(forKey: key(space, userID)) ?? []).isEmpty
  }
  public static func save(
    _ ids: [UUID], space: String, userID: UUID, defaults: UserDefaults = .standard
  ) {
    defaults.set(ids.map(\.uuidString), forKey: key(space, userID))
  }
  private static func key(_ space: String, _ userID: UUID) -> String {
    "taskOrder:" + space + ":" + userID.uuidString
  }
}
