import Foundation

public enum TaskOrdering {
  public static func orderedIDs(_ tasks: [TaskRecord], stored: [UUID]) -> [UUID] {
    let current = tasks.sorted {
      $0.createdAt != $1.createdAt ? $0.createdAt < $1.createdAt : $0.id.uuidString < $1.id.uuidString
    }.map(\.id)
    let available = Set(current)
    var seen = Set<UUID>()
    var result = stored.filter { available.contains($0) && seen.insert($0).inserted }
    result.append(contentsOf: current.filter { seen.insert($0).inserted })
    return result
  }
  public static func merging(_ selected: [UUID], into current: [UUID]) -> [UUID] {
    let ids = Set(selected)
    guard ids.count == selected.count, ids.isSubset(of: Set(current)) else { return current }
    var replacement = selected.makeIterator()
    return current.map { ids.contains($0) ? replacement.next()! : $0 }
  }
}
