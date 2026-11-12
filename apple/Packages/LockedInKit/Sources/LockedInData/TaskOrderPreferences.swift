import Foundation
import LockedInDomain

public enum TaskOrderPreferences {
  public static func orderedIDs(
    _ tasks: [TaskRecord], space: String, userID: UUID, defaults: UserDefaults = .standard
  ) -> [UUID] {
    let current = tasks.sorted {
      $0.createdAt != $1.createdAt
        ? $0.createdAt < $1.createdAt : $0.id.uuidString < $1.id.uuidString
    }.map(\.id)
    let available = Set(current)
    let stored =
      defaults.stringArray(forKey: key(space, userID))?.compactMap(UUID.init(uuidString:)) ?? []
    var seen = Set<UUID>()
    var ids = stored.filter { available.contains($0) && seen.insert($0).inserted }
    ids.append(contentsOf: current.filter { seen.insert($0).inserted })
    return ids
  }
  public static func merging(_ visible: [UUID], into current: [UUID]) -> [UUID] {
    let selected = Set(visible)
    guard selected.count == visible.count, selected.isSubset(of: Set(current)) else {
      return current
    }
    var replacement = visible.makeIterator()
    return current.map { selected.contains($0) ? replacement.next()! : $0 }
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
