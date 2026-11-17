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
      } else if destination == .overdue {
        ScrollView {
          LazyVStack(spacing: 6) {
            TaskReorderGroup(model: model, tasks: tasks, session: taskDragSession, open: open,
              includeHiddenProjectParents: false, restrictedMenu: true)
          }.padding(.horizontal, 16).padding(.vertical, 8)
        }.refreshable { await model.refresh() }
      } else {
        List {
          TaskReorderGroup(model: model, tasks: tasks, session: taskDragSession, open: open, reorderEnabled: destination != .completed,
            includeHiddenProjectParents: destination != .today && destination != .overdue && destination != .completed,
            newestCompletedFirst: destination == .completed)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }.listStyle(.plain).refreshable { await model.refresh() }
      }
    }.onDisappear { taskDragSession.reset() }
  }
  private var subtitle: String {
    if destination == .overdue { return "Пропущенные планы и задачи с истёкшим дедлайном." }
    return destination == .inbox
      ? "Сначала запиши. Разберёшь потом." : "Одно место для всего, что важно."
  }
}

private struct MergedTaskCardKey: EnvironmentKey {
  static let defaultValue = false
}
private struct CenteredTaskInspectorKey: EnvironmentKey {
  static let defaultValue = true
}
extension EnvironmentValues {
  var mergedTaskCard: Bool {
    get { self[MergedTaskCardKey.self] }
    set { self[MergedTaskCardKey.self] = newValue }
  }
  var centeredTaskInspector: Bool {
    get { self[CenteredTaskInspectorKey.self] }
    set { self[CenteredTaskInspectorKey.self] = newValue }
  }
}

struct TaskRow: View {
  @Bindable var model: AppModel
  var task: TaskRecord
  var open: () -> Void
  var restrictedMenu = false
  @State private var showInspector = false
  @State private var confirmDelete = false
  @State private var completing = false
  private var displayedCompleted: Bool { task.completed || completing }
  @Environment(\.mergedTaskCard) private var mergedCard
  @Environment(\.centeredTaskInspector) private var centeredInspector
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
        guard !completing else { return }
        if task.completed {
          model.perform(.completed(task.id, false))
        } else {
          withAnimation(.snappy(duration: 0.15, extraBounce: 0)) { completing = true }
          Task { @MainActor in
            do {
              try await Task.sleep(for: .milliseconds(180))
              try await model.mutate(.completed(task.id, true))
            } catch { model.errorMessage = model.friendly(error) }
            withAnimation(.smooth(duration: 0.12)) { completing = false }
          }
        }
      } label: {
        Image(systemName: displayedCompleted ? "checkmark.circle.fill" : "circle").font(
          .system(size: 17)
        )
        .foregroundStyle(displayedCompleted ? Color.accent : Color.secondary.opacity(0.6))
        .contentTransition(.symbolEffect(.replace))
      }.buttonStyle(.plain).disabled(!model.canEdit || completing).padding(.top, 2)
        .accessibilityLabel(task.completed ? "Вернуть в работу" : "Завершить задачу")
      Button(action: openInspector) {
        VStack(alignment: .leading, spacing: 3) {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(task.title).font(.body.weight(.medium)).strikethrough(displayedCompleted)
              .foregroundStyle(task.completed ? .secondary : .primary)
            PendingSyncBadge(pending: model.visibleUnsyncedTaskIDs.contains(task.id))
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
            TaskTagStyle.label(model.snapshot.tags.filter { task.tagIDs.contains($0.id) })
              .font(.caption).lineLimit(2)
          }
        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain)
      let urls = TaskLinks(stored: task.description).urls
      if let url = urls.first {
        Link(destination: url) {
          HStack(spacing: 2) {
            Image(systemName: "link").font(.system(size: 12, weight: .medium))
              .frame(width: 22, height: 22)
            if urls.count > 1 {
              Text("+\(urls.count - 1)").font(.caption2.weight(.medium)).monospacedDigit()
            }
          }.foregroundStyle(Color.accent).fixedSize().contentShape(Rectangle())
        }.buttonStyle(.plain).help(url.absoluteString)
          .accessibilityLabel("Открыть ссылку задачи")
          .accessibilityValue("Ссылок: \(urls.count)")
          .accessibilityHint(url.absoluteString)
      }
    }
    .padding(.horizontal, 10).padding(.vertical, 8)
    .background(mergedCard ? Color.clear : Color.taskCardSurface, in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).strokeBorder(
        showInspector && !restrictedMenu ? Color.accent : .clear, lineWidth: 1.5)
    }
    #if os(macOS)
      .background {
        MacTaskInspector(model: model, task: task, centered: centeredInspector, isPresented: $showInspector).allowsHitTesting(
          false)
      }
    #endif
    .contextMenu {
      if !mergedCard || task.parentID != nil {
      if restrictedMenu {
        Button("Запланировать заново", systemImage: "calendar.badge.clock") {
          #if os(macOS)
            showInspector = true
          #else
            open()
          #endif
        }.disabled(!model.canEdit)
        Button("Удалить задачу", role: .destructive) { confirmDelete = true }
          .disabled(!model.canEdit)
      } else {
      Button("Удалить задачу", role: .destructive) { confirmDelete = true }
        .disabled(!model.canEdit)
      Menu("Добавить тег") {
        if model.snapshot.tags.isEmpty { Text("Пока нет тегов") }
        ForEach(model.snapshot.tags) { tag in
          Toggle(tag.name, isOn: Binding(
            get: { task.tagIDs.contains(tag.id) },
            set: { selected in
              guard let current = model.snapshot.tasks.first(where: { $0.id == task.id }) else { return }
              var input = TaskInput(current)
              input.tagIDs.removeAll { $0 == tag.id }
              if selected { input.tagIDs.append(tag.id) }
              model.perform(.task(task.id, input))
            }))
        }
      }.disabled(!model.canEdit)
      TaskCalendarMenuItem(model: model, task: task) {
        #if os(macOS)
          showInspector = true
        #else
          open()
        #endif
      }
      Button("Преобразовать в проект") { model.convertToProject(task.id) }.disabled(!model.canEdit || task.parentID != nil
        || model.snapshot.tasks.contains { $0.parentID == task.id })
      Menu("Переместить в список") {
        Button("Входящие") { model.move(task.id, to: nil, includingProject: false) }
        ForEach(model.snapshot.rootLists) { list in
          Button(list.name) { model.move(task.id, to: list.id, includingProject: false) }
        }
      }.disabled(!model.canEdit)
      Menu("Переместить в проект") {
        ForEach(model.projectDestinations(for: task)) { project in
          Button(project.title) { model.moveTask(task.id, intoProject: project.id) }
        }
      }.disabled(!model.canEdit || model.projectDestinations(for: task).isEmpty)
      }
      }
    }
    .confirmationDialog("Удалить задачу?", isPresented: $confirmDelete, titleVisibility: .visible) {
      Button("Удалить", role: .destructive) { model.perform(.deleteTask(task.id)) }
      Button("Отмена", role: .cancel) {}
    }
  }
}
