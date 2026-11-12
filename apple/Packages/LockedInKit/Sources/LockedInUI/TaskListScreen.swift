import LockedInDomain
import SwiftUI

struct TaskListScreen: View {
  @Bindable var model: AppModel
  let destination: Destination
  var search: String
  var showCompleted: Bool
  var open: (TaskRecord) -> Void
  var create: () -> Void
  @State private var taskDragSession = BoardReorderSession(kind: .task)
  private var tasks: [TaskRecord] {
    model.orderedTasks(
      destination.tasks(in: model.snapshot).filter {
        (showCompleted || destination == .completed || !$0.completed)
          && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search)
            || ($0.description?.localizedCaseInsensitiveContains(search) ?? false))
      }
    ).sorted { left, right in
      if left.completed != right.completed { return !left.completed }
      return false
    }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text(
            destination == .today
              ? Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)) : subtitle
          )
          .font(.subheadline).foregroundStyle(.secondary)
          Text("\(tasks.count) задач").font(.largeTitle.bold())
        }
        Spacer()
        Button(action: create) { Label("Добавить", systemImage: "plus") }.buttonStyle(
          .borderedProminent
        )
        .disabled(!model.canEdit)
      }.padding(24)
      if tasks.isEmpty {
        EmptyState(
          symbol: search.isEmpty ? "checklist" : "magnifyingglass",
          title: search.isEmpty ? "Здесь пока спокойно" : "Ничего не найдено",
          message: search.isEmpty
            ? "Запиши первую задачу. Для начала достаточно названия."
            : "Попробуй другое название или очисти поиск.",
          action: search.isEmpty && model.canEdit ? create : nil)
      } else {
        List {
          TaskReorderGroup(model: model, tasks: tasks, session: taskDragSession, open: open)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }.listStyle(.plain).refreshable { await model.refresh() }
      }
    }.onDisappear { taskDragSession.reset() }
  }
  private var subtitle: String {
    return destination == .inbox
      ? "Сначала запиши. Разберёшь потом." : "Одно место для всего, что важно."
  }
}

struct TaskRow: View {
  @Bindable var model: AppModel
  var task: TaskRecord
  var open: () -> Void
  @State private var showInspector = false
  private func openInspector() {
    #if os(macOS)
      showInspector.toggle()
    #else
      open()
    #endif
  }
  private var isOverdue: Bool {
    guard !task.completed else { return false }
    if let date = task.deadlineAt { return date < .now }
    if let date = task.deadlineDate.flatMap(DateOnly.parse) {
      return date < Calendar.current.startOfDay(for: .now)
    }
    return false
  }
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Button {
        model.perform(.completed(task.id, !task.completed))
      } label: {
        Image(systemName: task.completed ? "checkmark.circle.fill" : "circle").font(
          .system(size: 17)
        )
        .foregroundStyle(task.completed ? Color.accent : Color.secondary.opacity(0.6))
      }.buttonStyle(.plain).disabled(!model.canEdit).padding(.top, 2)
        .accessibilityLabel(task.completed ? "Вернуть в работу" : "Завершить задачу")
      Button(action: openInspector) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(task.title).font(.body.weight(.medium)).strikethrough(task.completed)
              .foregroundStyle(task.completed ? .secondary : .primary)
            Spacer(minLength: 0)
            if task.deadlineDate != nil || task.deadlineAt != nil {
              Image(systemName: "flag.fill").font(.caption).foregroundStyle(.orange)
            }
          }
          if let date = task.deadlineAt ?? task.deadlineDate.flatMap(DateOnly.parse)
            ?? task.plannedAt
          {
            Text(
              date.formatted(
                task.deadlineDate != nil && task.deadlineAt == nil
                  ? .dateTime.day().month() : .dateTime.day().month().hour().minute())
            )
            .font(.caption).foregroundStyle(isOverdue ? Color.red : Color.secondary)
          }
          if !task.tagIDs.isEmpty {
            Text(
              model.snapshot.tags.filter { task.tagIDs.contains($0.id) }.map { "#" + $0.name }
                .joined(separator: "  ")
            )
            .font(.caption).foregroundStyle(Color.blue.opacity(0.8)).lineLimit(2)
          }
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain)
    }
    .padding(.horizontal, 10).padding(.vertical, 8)
    .background(Color.taskCardSurface, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).strokeBorder(
        showInspector ? Color.accent : .clear, lineWidth: 1.5)
    }
    #if os(macOS)
      .background {
        MacTaskInspector(model: model, task: task, isPresented: $showInspector).allowsHitTesting(
          false)
      }
    #endif
    .contextMenu {
      Button("Открыть задачу", action: openInspector)
      Menu("Переместить в список") {
        Button("Входящие") { model.move(task.id, to: nil) }
        ForEach(model.snapshot.rootLists) { list in
          Button(list.name) { model.move(task.id, to: list.id) }
        }
      }.disabled(!model.canEdit)
    }
  }
}
