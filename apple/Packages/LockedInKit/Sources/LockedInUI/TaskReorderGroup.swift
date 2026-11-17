import LockedInDomain
import SwiftUI
import UniformTypeIdentifiers

struct TaskReorderGroup: View {
  @Bindable var model: AppModel
  var tasks: [TaskRecord]
  var session: BoardReorderSession
  var open: (TaskRecord) -> Void
  var listDrop: BoardDropDelegate? = nil
  var reorderEnabled = true
  var includeHiddenProjectParents = true
  var restrictedMenu = false
  var newestCompletedFirst = false
  @State private var newChild: TaskPresentation?
  @State private var deletingProject: TaskRecord?
  var destinationListID: UUID? = nil
  private var previewTasks: [TaskRecord] {
    var result = tasks
    if let source = session.source, let placement = session.placement,
      var moving = model.snapshot.tasks.first(where: { $0.id == source }) {
      let children = model.snapshot.tasks.filter { $0.parentID == source }
      result.removeAll { $0.id == source || $0.parentID == source }
      moving.parentID = placement.parentID
      moving.listID = placement.listID
      if placement.listID == destinationListID || listDrop == nil {
        result.append(moving)
        result.append(contentsOf: children)
      }
    }
    return result
  }
  private var roots: [TaskRecord] {
    let visible = previewTasks
    let ids = Set(visible.map(\.id))
    let context = includeHiddenProjectParents ? previewSnapshot : previewSnapshot.filter { ids.contains($0.id) }
    return ordered(TaskProjectGrouping.roots(visible: visible, all: context))
  }
  private var previewSnapshot: [TaskRecord] {
    var all = model.snapshot.tasks
    if let source = session.source, let placement = session.placement,
      let index = all.firstIndex(where: { $0.id == source }) {
      all[index].parentID = placement.parentID
      all[index].listID = placement.listID
    }
    return all
  }
  private func ordered(_ records: [TaskRecord]) -> [TaskRecord] {
    if newestCompletedFirst {
      return records.sorted {
        if $0.updatedAt != $1.updatedAt { return $0.updatedAt > $1.updatedAt }
        if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
        return $0.id.uuidString < $1.id.uuidString
      }
    }
    guard session.source != nil else { return model.orderedTasks(records) }
    let positions = Dictionary(uniqueKeysWithValues: session.order.enumerated().map { ($0.element, $0.offset) })
    return model.orderedTasks(records).sorted { positions[$0.id, default: Int.max] < positions[$1.id, default: Int.max] }
  }
  private var ids: [UUID] { roots.map(\.id) }
  private func begin(_ id: UUID) -> NSItemProvider {
    session.begin(id, order: model.orderedTasks(model.snapshot.tasks).map(\.id))
  }
  var body: some View {
    ForEach(ids, id: \.self) { id in
      if let task = roots.first(where: { $0.id == id }) {
        projectCard(task)
          .transition(.asymmetric(insertion: .opacity,
            removal: .scale(scale: 0.88).combined(with: .opacity)))
          .overlay {
            RoundedRectangle(cornerRadius: 12)
              .strokeBorder(session.projectTarget == id ? Color.accent : .clear, lineWidth: 2)
              .allowsHitTesting(false)
          }
          .contentShape(Rectangle())
          .modifier(ReorderDragSource(id: id, provider: { begin(id) }, enabled: reorderEnabled))
          .opacity(session.source == id ? 0.18 : 1)
          .modifier(TaskPlacementTarget(model: model, target: task,
            session: session, listDrop: listDrop, enabled: reorderEnabled))
      }
    }
    .animation(.snappy(duration: 0.12, extraBounce: 0), value: ids)
    .sheet(item: $newChild) { TaskEditor(model: model, presentation: $0) }
    .confirmationDialog("Удалить проект со всеми задачами?", isPresented: Binding(
      get: { deletingProject != nil }, set: { if !$0 { deletingProject = nil } }
    ), titleVisibility: .visible) {
      if let project = deletingProject {
        Button("Удалить", role: .destructive) {
          let children = model.snapshot.tasks.filter { $0.parentID == project.id }
          Task {
            do {
              for child in children { try await model.mutate(.deleteTask(child.id)) }
              try await model.mutate(.deleteTask(project.id))
            } catch { model.errorMessage = model.friendly(error) }
          }
        }
      }
      Button("Отмена", role: .cancel) { deletingProject = nil }
    }
  }
  private func projectCard(_ task: TaskRecord) -> some View {
    let children = ordered(previewTasks.filter { $0.parentID == task.id })
    let allChildren = previewSnapshot.filter { $0.parentID == task.id }
    let isProject = task.isProject == true || !allChildren.isEmpty || (session.source != nil && model.snapshot.tasks.contains { $0.parentID == task.id })
    return VStack(spacing: 0) {
      TaskRow(model: model, task: task, open: { open(task) }, restrictedMenu: restrictedMenu)
        .modifier(TaskPlacementTarget(model: model, target: task,
          projectHeader: isProject, session: session, listDrop: listDrop, enabled: reorderEnabled))
      if isProject {
        HStack(spacing: 5) {
          Image(systemName: "square.stack")
          Text("Проект · \(allChildren.filter(\.completed).count)/\(allChildren.count)")
          Spacer(minLength: 0)
        }.font(.caption2).foregroundStyle(.secondary)
          .padding(.horizontal, 12).padding(.bottom, 7)
        ForEach(children) { child in
          Divider().padding(.leading, 35).padding(.trailing, 10)
          TaskRow(model: model, task: child, open: { open(child) }, restrictedMenu: restrictedMenu)
            .padding(.leading, 16)
            .modifier(ReorderDragSource(id: child.id, provider: { begin(child.id) }, enabled: reorderEnabled))
            .opacity(session.source == child.id ? 0.18 : 1)
            .modifier(TaskPlacementTarget(model: model, target: child,
              session: session, listDrop: listDrop, enabled: reorderEnabled))
            .transition(.scale(scale: 0.88).combined(with: .opacity))
        }
      }
    }
    .environment(\.mergedTaskCard, isProject)
    .background(isProject ? Color.taskCardSurface : Color.clear, in: RoundedRectangle(cornerRadius: 12))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .contentShape(RoundedRectangle(cornerRadius: 12))
    .modifier(ProjectContextMenu(enabled: isProject) {
      if !restrictedMenu {
        Button("Добавить новую задачу") {
          newChild = TaskPresentation(input: TaskInput(listID: task.listID, parentID: task.id))
        }.disabled(!model.canEdit)
        Button("Расформировать проект") { model.dissolveProject(task.id) }
          .disabled(!model.canEdit)
      }
      if restrictedMenu {
        Button("Запланировать заново", systemImage: "calendar.badge.clock") { open(task) }
          .disabled(!model.canEdit)
      } else {
        TaskCalendarMenuItem(model: model, task: task, replan: { open(task) })
      }
        Button("Удалить проект", role: .destructive) { deletingProject = task }
          .disabled(!model.canEdit)
      if !restrictedMenu {
        Menu("Переместить в список") {
          Button("Входящие") { model.move(task.id, to: nil) }
          ForEach(model.snapshot.rootLists) { list in
            Button(list.name) { model.move(task.id, to: list.id) }
          }
        }.disabled(!model.canEdit)
      }
    })
    .animation(.snappy(duration: 0.12, extraBounce: 0), value: children.map(\.id))
  }

}

// An empty contextMenu on the wrapper masks the task's own menu in a plain List.
private struct ProjectContextMenu<Items: View>: ViewModifier {
  var enabled: Bool
  @ViewBuilder var items: () -> Items
  @ViewBuilder func body(content: Content) -> some View {
    if enabled { content.contextMenu(menuItems: items) }
    else { content }
  }
}
