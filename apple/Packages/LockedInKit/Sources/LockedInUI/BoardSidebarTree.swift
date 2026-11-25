import Foundation
import LockedInDomain

struct BoardSidebarTree {
  struct Entry: Identifiable {
    let board: BoardRecord
    let depth: Int
    let hasChildren: Bool
    var id: UUID { board.id }
  }
  let boards: [BoardRecord]
  var order: [UUID] = []

  func entries(collapsed: Set<UUID>) -> [Entry] {
    let generalID = boards.first(where: \.isGeneral)?.id
    let positions = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
    func precedes(_ left: BoardRecord, _ right: BoardRecord) -> Bool {
      let leftPosition = positions[left.id, default: Int.max]
      let rightPosition = positions[right.id, default: Int.max]
      if leftPosition != rightPosition { return leftPosition < rightPosition }
      if left.createdAt != right.createdAt { return left.createdAt < right.createdAt }
      return left.id.uuidString < right.id.uuidString
    }
    let children = Dictionary(grouping: boards.filter { $0.parentID != nil }, by: { $0.parentID! })
    var result: [Entry] = []
    var seen = Set<UUID>()
    func append(_ board: BoardRecord, depth: Int) {
      guard seen.insert(board.id).inserted else { return }
      let descendants = children[board.id, default: []].sorted(by: precedes)
      result.append(Entry(board: board, depth: depth, hasChildren: !descendants.isEmpty))
      guard !collapsed.contains(board.id) else { return }
      for child in descendants { append(child, depth: depth + 1) }
    }
    for board in boards.filter({ !$0.isGeneral && ($0.parentID == nil || $0.parentID == generalID) })
      .sorted(by: precedes) {
      append(board, depth: 0)
    }
    return result
  }

  func reorderTarget(source: UUID, hovered: UUID) -> UUID? {
    let byID = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, $0) })
    let generalID = boards.first(where: \.isGeneral)?.id
    guard let moving = byID[source], !moving.isGeneral else { return nil }
    func group(_ board: BoardRecord) -> UUID? { board.parentID == generalID ? nil : board.parentID }
    let sourceGroup = group(moving)
    var current = byID[hovered]
    var seen = Set<UUID>()
    while let board = current, !board.isGeneral, seen.insert(board.id).inserted {
      if group(board) == sourceGroup { return board.id }
      current = board.parentID.flatMap { byID[$0] }
    }
    return nil
  }

  func ancestors(of id: UUID) -> Set<UUID> {
    let byID = Dictionary(uniqueKeysWithValues: boards.map { ($0.id, $0) })
    var result = Set<UUID>()
    var next = byID[id]?.parentID
    while let parentID = next, result.insert(parentID).inserted {
      next = byID[parentID]?.parentID
    }
    return result
  }
}
