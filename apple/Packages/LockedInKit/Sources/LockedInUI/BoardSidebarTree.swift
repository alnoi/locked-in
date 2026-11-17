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

  func entries(collapsed: Set<UUID>) -> [Entry] {
    let generalID = boards.first(where: \.isGeneral)?.id
    let children = Dictionary(grouping: boards.filter { $0.parentID != nil }, by: { $0.parentID! })
    var result: [Entry] = []
    var seen = Set<UUID>()
    func append(_ board: BoardRecord, depth: Int) {
      guard seen.insert(board.id).inserted else { return }
      let descendants = children[board.id, default: []].sorted { $0.createdAt < $1.createdAt }
      result.append(Entry(board: board, depth: depth, hasChildren: !descendants.isEmpty))
      guard !collapsed.contains(board.id) else { return }
      for child in descendants { append(child, depth: depth + 1) }
    }
    for board in boards.filter({ !$0.isGeneral && ($0.parentID == nil || $0.parentID == generalID) })
      .sorted(by: { $0.createdAt < $1.createdAt }) {
      append(board, depth: 0)
    }
    return result
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
