import Foundation
import LockedInDomain

enum UndoGrouping {
  @TaskLocal static var id: UUID?
  @TaskLocal static var replaying = false
}

enum UndoOperation {
  case change(Change)
  case taskOrder([UUID])
  case listOrder([UUID])
}

@MainActor final class ActionHistory {
  struct Entry {
    var id: UUID
    var operations: [UndoOperation]
  }
  private var source: String?
  private(set) var entries: [Entry] = []
  var isUndoing = false
  var activeGroups = Set<UUID>()

  func prepare(source: String) {
    if self.source != source {
      entries.removeAll()
      self.source = source
    }
  }
  func record(_ operations: [UndoOperation]) {
    guard !UndoGrouping.replaying, !operations.isEmpty else { return }
    let id = UndoGrouping.id ?? UUID()
    if entries.last?.id == id {
      entries[entries.count - 1].operations.insert(contentsOf: operations, at: 0)
    } else {
      entries.append(Entry(id: id, operations: operations))
      if entries.count > 100 { entries.removeFirst() }
    }
  }
  func acknowledge(_ id: UUID) {
    guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
    entries[index].operations.removeFirst()
    if entries[index].operations.isEmpty { entries.remove(at: index) }
  }
  func record(_ result: ChangeResult, before: Snapshot, taskOrder: [UUID], listOrder: [UUID]) {
    var changes: [Change] = []
    switch result {
    case .task(let value):
      if let old = before.tasks.first(where: { $0.id == value.id }) {
        if TaskInput(old) != TaskInput(value) {
          var input = TaskInput(old)
          input.inheritProjectTags = false
          changes.append(.task(old.id, input))
        }
        if old.completed != value.completed { changes.append(.completed(old.id, old.completed)) }
      } else { changes = [.deleteTask(value.id)] }
    case .board(let value):
      changes = before.boards.first(where: { $0.id == value.id }).map { [.board($0.id, BoardInput($0))] }
        ?? [.deleteBoard(value.id)]
    case .list(let value):
      changes = before.lists.first(where: { $0.id == value.id }).map { [.list($0.id, ListInput($0))] }
        ?? [.deleteList(value.id)]
    case .tag(let value):
      changes = before.tags.first(where: { $0.id == value.id }).map { [.tag($0.id, name: $0.name, color: $0.color ?? "#777777")] }
        ?? [.deleteTag(value.id)]
    case .comment(let value):
      changes = before.comments.first(where: { $0.id == value.id }).map { [.comment($0.id, taskID: $0.taskID, text: $0.text)] }
        ?? [.deleteComment(value.id)]
    case .deleted(let kind, let id):
      switch kind {
      case .task:
        if let old = before.tasks.first(where: { $0.id == id }) {
          changes = [.restore(.task(old))]
          changes += before.comments.filter { $0.taskID == id }.map { .restore(.comment($0)) }
        }
      case .board:
        if let old = before.boards.first(where: { $0.id == id }) { changes = [.restore(.board(old))] }
      case .list:
        if let old = before.lists.first(where: { $0.id == id }) {
          changes = [.restore(.list(old))]
          changes += before.tasks.filter { $0.listID == id }.map { .task($0.id, TaskInput($0)) }
        }
      case .tag:
        if let old = before.tags.first(where: { $0.id == id }) { changes = [.restore(.tag(old))] }
      case .comment:
        if let old = before.comments.first(where: { $0.id == id }) { changes = [.restore(.comment(old))] }
      }
    }
    guard !changes.isEmpty else { return }
    record(changes.map { .change($0) } + [.taskOrder(taskOrder), .listOrder(listOrder)])
  }
}
