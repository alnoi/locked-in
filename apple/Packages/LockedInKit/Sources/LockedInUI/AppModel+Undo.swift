import Foundation
import LockedInData
import LockedInDomain

extension AppModel {
  func prepareActionHistory() {
    actionHistory.prepare(source: settings.identity + ":" + snapshot.user.id.uuidString)
  }
  func groupedUndo<Result>(_ operation: () throws -> Result) rethrows -> Result {
    try UndoGrouping.$id.withValue(UndoGrouping.id ?? UUID(), operation: operation)
  }
  func groupedUndo<Result>(_ operation: () async throws -> Result) async rethrows -> Result {
    let id = UndoGrouping.id ?? UUID()
    let inserted = actionHistory.activeGroups.insert(id).inserted
    defer { if inserted { actionHistory.activeGroups.remove(id) } }
    return try await UndoGrouping.$id.withValue(id) { try await operation() }
  }
  func undoLastAction() {
    guard hasLoaded, !isLoading, !actionHistory.isUndoing else { return }
    actionHistory.isUndoing = true
    Task { @MainActor in
      defer {
        actionHistory.isUndoing = false
        undoRevision += 1
      }
      while isMutating || !actionHistory.activeGroups.isEmpty { await Task.yield() }
      prepareActionHistory()
      guard let entry = actionHistory.entries.last else { return }
      do {
        try await UndoGrouping.$replaying.withValue(true) {
          for operation in entry.operations {
            switch operation {
            case .change(let change): _ = try await mutate(change)
            case .taskOrder(let ids): saveTaskOrder(ids)
            case .listOrder(let ids): saveListOrder(ids)
            }
            actionHistory.acknowledge(entry.id)
          }
        }
      } catch { errorMessage = "Не удалось отменить действие. " + friendly(error) }
    }
  }
  func deleteProjectAndWait(_ id: UUID) async throws {
    try await groupedUndo {
      for child in snapshot.tasks.filter({ $0.parentID == id }) {
        try await mutate(.deleteTask(child.id))
      }
      try await mutate(.deleteTask(id))
    }
  }
}
