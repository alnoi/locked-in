import Foundation

public enum TaskProjectGrouping {
  public static func root(of task: TaskRecord, in tasks: [TaskRecord]) -> TaskRecord {
    task.parentID.flatMap { parent in tasks.first { $0.id == parent } } ?? task
  }
  public static func roots(visible: [TaskRecord], all: [TaskRecord]) -> [TaskRecord] {
    var seen = Set<UUID>()
    return visible.compactMap { task in
      let root = root(of: task, in: all)
      return seen.insert(root.id).inserted ? root : nil
    }
  }
  public static func listID(of task: TaskRecord, in tasks: [TaskRecord]) -> UUID? {
    root(of: task, in: tasks).listID
  }
}
