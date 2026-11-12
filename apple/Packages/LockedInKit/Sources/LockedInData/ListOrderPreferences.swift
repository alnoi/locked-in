import Foundation
import LockedInDomain

public enum ListOrderPreferences {
  public static func apply(
    to snapshot: inout Snapshot, space: String, defaults: UserDefaults = .standard
  ) {
    let ids = orderedIDs(snapshot.lists, space: space, userID: snapshot.user.id, defaults: defaults)
    let positions = Dictionary(
      uniqueKeysWithValues: ids.enumerated().map { ($0.element, $0.offset) })
    for i in snapshot.lists.indices {
      snapshot.lists[i].position = positions[snapshot.lists[i].id] ?? i
    }
    let saved = ids.map(\.uuidString)
    defaults.set(saved, forKey: key(space, snapshot.user.id))
  }
  public static func orderedIDs(
    _ lists: [TaskList], space: String, userID: UUID, defaults: UserDefaults = .standard
  ) -> [UUID] {
    let current = ListOrdering.sorted(lists).map(\.id)
    let available = Set(current + [ListOrdering.inboxID])
    var stored =
      defaults.stringArray(forKey: key(space, userID))?.compactMap(UUID.init(uuidString:))
      ?? current
    if !stored.contains(ListOrdering.inboxID) { stored.insert(ListOrdering.inboxID, at: 0) }
    var seen = Set<UUID>()
    var ids = stored.filter { available.contains($0) && seen.insert($0).inserted }
    ids.append(contentsOf: current.filter { seen.insert($0).inserted })
    return ids
  }
  public static func saveIDs(
    _ ids: [UUID], space: String, userID: UUID, defaults: UserDefaults = .standard
  ) {
    defaults.set(ids.map(\.uuidString), forKey: key(space, userID))
  }
  public static func save(
    _ lists: [TaskList], space: String, userID: UUID, defaults: UserDefaults = .standard
  ) {
    defaults.set(ListOrdering.sorted(lists).map { $0.id.uuidString }, forKey: key(space, userID))
  }
  private static func key(_ space: String, _ userID: UUID) -> String {
    "listOrder:" + space + ":" + userID.uuidString
  }
}
