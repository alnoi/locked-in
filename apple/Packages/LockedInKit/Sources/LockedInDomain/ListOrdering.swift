import Foundation

public enum ListOrdering {
  public static let inboxID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
  public static func preview(moving: UUID, over target: UUID, ids: [UUID]) -> [UUID] {
    guard moving != target, let from = ids.firstIndex(of: moving),
      let to = ids.firstIndex(of: target)
    else { return ids }
    var result = ids
    result.insert(result.remove(at: from), at: to)
    return result
  }
  public static func sorted(_ lists: [TaskList]) -> [TaskList] {
    lists.sorted {
      if $0.position != $1.position { return $0.position < $1.position }
      if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
      return false
    }
  }
  public static func move(_ id: UUID, before: UUID?, lists: [TaskList]) throws -> [TaskList] {
    if before == id {
      throw TrackerError.validation("Нельзя переместить список перед самим собой.")
    }
    var values = sorted(lists)
    guard let source = values.firstIndex(where: { $0.id == id }) else {
      throw TrackerError.notFound
    }
    let item = values.remove(at: source)
    let index: Int
    if let before {
      guard let destination = values.firstIndex(where: { $0.id == before }) else {
        throw TrackerError.notFound
      }
      index = destination
    } else {
      index = values.count
    }
    values.insert(item, at: index)
    for i in values.indices { values[i].position = i }
    return values
  }
  public static func targetBefore(moving: UUID, over target: UUID, visible: [TaskList]) -> UUID? {
    let lists = sorted(visible)
    guard let from = lists.firstIndex(where: { $0.id == moving }),
      let to = lists.firstIndex(where: { $0.id == target })
    else { return target }
    if from < to { return to + 1 < lists.count ? lists[to + 1].id : nil }
    return target
  }
}
