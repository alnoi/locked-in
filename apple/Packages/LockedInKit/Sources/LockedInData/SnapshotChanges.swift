import Foundation
import LockedInDomain

extension Snapshot {
  public mutating func receive(_ result: ChangeResult) {
    switch result {
    case .task(let record):
      tasks.removeAll { $0.id == record.id }
      tasks.append(record)
    case .board(let record):
      boards.removeAll { $0.id == record.id }
      boards.append(record)
    case .list(let record):
      lists.removeAll { $0.id == record.id }
      lists.append(record)
    case .tag(let record):
      tags.removeAll { $0.id == record.id }
      tags.append(record)
    case .comment(let record):
      comments.removeAll { $0.id == record.id }
      comments.append(record)
    case .deleted(let kind, let id):
      switch kind {
      case .task:
        tasks.removeAll { $0.id == id }
        comments.removeAll { $0.taskID == id }
      case .board: boards.removeAll { $0.id == id }
      case .list:
        lists.removeAll { $0.id == id }
        for index in tasks.indices where tasks[index].listID == id {
          tasks[index].listID = nil
          tasks[index].updatedAt = .now
        }
      case .tag: tags.removeAll { $0.id == id }
      case .comment: comments.removeAll { $0.id == id }
      }
    }
  }
}
