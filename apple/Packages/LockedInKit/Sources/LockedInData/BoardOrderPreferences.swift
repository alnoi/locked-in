import Foundation
import LockedInDomain

public enum BoardOrderPreferences {
  public static func orderedIDs(_ boards: [BoardRecord], space: String, userID: UUID,
    defaults: UserDefaults = .standard) -> [UUID] {
    let current = boards.filter { !$0.isGeneral }.sorted {
      $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.id.uuidString < $1.id.uuidString
    }.map(\.id)
    let available = Set(current)
    let stored = defaults.stringArray(forKey: key(space, userID))?.compactMap(UUID.init(uuidString:)) ?? []
    var seen = Set<UUID>()
    var result = stored.filter { available.contains($0) && seen.insert($0).inserted }
    result.append(contentsOf: current.filter { seen.insert($0).inserted })
    return result
  }
  public static func save(_ ids: [UUID], space: String, userID: UUID, defaults: UserDefaults = .standard) {
    defaults.set(ids.map(\.uuidString), forKey: key(space, userID))
  }
  private static func key(_ space: String, _ userID: UUID) -> String {
    "boardOrder:" + space + ":" + userID.uuidString
  }
}
