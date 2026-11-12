import LockedInDomain
import SwiftUI
import UniformTypeIdentifiers

struct TaskReorderGroup: View {
  @Bindable var model: AppModel
  var tasks: [TaskRecord]
  var session: BoardReorderSession
  var open: (TaskRecord) -> Void
  var listDrop: BoardDropDelegate? = nil
  private var ids: [UUID] {
    if let source = session.source, tasks.contains(where: { $0.id == source }) {
      return session.order
    }
    return model.orderedTasks(tasks).map(\.id)
  }
  var body: some View {
    ForEach(ids, id: \.self) { id in
      if let task = tasks.first(where: { $0.id == id }) {
        TaskRow(model: model, task: task, open: { open(task) })
          .contentShape(Rectangle())
          .modifier(ReorderDragSource(id: id, provider: { session.begin(id, order: model.orderedTasks(tasks).map(\.id)) }))
          .opacity(session.source == id ? 0.18 : 1)
          .onDrop(
            of: [UTType.text.identifier],
            delegate: TaskReorderDropDelegate(
              target: id, session: session, commit: model.saveTaskOrder, listDrop: listDrop))
      }
    }
  }
}
