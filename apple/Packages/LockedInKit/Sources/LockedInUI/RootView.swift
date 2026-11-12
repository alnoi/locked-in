import LockedInData
import LockedInDomain
import SwiftUI

public struct LockedInRootView: View {
  #if os(macOS)
    @Environment(\.openWindow) private var openWindow
  #endif
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  @Bindable private var model: AppModel
  @State private var destination: Destination? = .board
  @State private var columnVisibility = NavigationSplitViewVisibility.all
  @State private var compactColumn = NavigationSplitViewColumn.detail
  @State private var search = ""
  @State private var taskPresentation: TaskPresentation?
  @State private var boardPresentation: BoardPresentation?
  @State private var listPresentation: ListPresentation?
  @State private var showSettings = false
  @State private var showCompleted = false
  public init(model: AppModel) { self.model = model }
  public var body: some View {
    NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn)
    {
      sidebar
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    } detail: {
      NavigationStack {
        VStack(spacing: 0) {
          if model.isOffline && model.hasLoaded {
            HStack {
              Image(systemName: "wifi.slash")
              Text("Нет связи · сохранённая копия доступна для просмотра")
              Spacer()
              Button("Повторить") { Task { await model.refresh() } }
            }.font(.caption).padding(10).background(.orange.opacity(0.1))
          }
          if let warning = model.reminderWarning {
            HStack {
              Image(systemName: "bell.badge")
              Text(warning)
              Spacer()
              Button("Разрешить") { Task { await model.requestReminderPermissions() } }
              Button("Настройки") { openURL(TaskAlertScheduler.permissionSettingsURL) }
            }
            .font(.caption).padding(10).background(.orange.opacity(0.1))
          }
          content
        }
        .navigationTitle((destination ?? .calendar).title(in: model.snapshot))
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $search, prompt: "Найти задачу")
        .toolbar {
          ToolbarItemGroup(placement: .primaryAction) {
            if model.isLoading || model.isMutating { ProgressView().controlSize(.small) }
            Button {
              Task { await model.refresh() }
            } label: {
              Label("Обновить", systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading || model.isMutating).keyboardShortcut(
              "r", modifiers: .command)
            Button {
              addTask()
            } label: {
              Label("Новая задача", systemImage: "plus")
            }
            .disabled(!model.canEdit).keyboardShortcut("n", modifiers: .command)
          }
          ToolbarItem(placement: .automatic) {
            Menu {
              Toggle("Показывать завершённые", isOn: $showCompleted)
              Button("Новая доска", systemImage: "rectangle.stack.badge.plus") {
                boardPresentation = BoardPresentation()
              }
              Button("Новый список", systemImage: "folder.badge.plus") { newList() }
              if let id = currentBoardID,
                let board = model.snapshot.boards.first(where: { $0.id == id })
              {
                Button("Настроить доску", systemImage: "slider.horizontal.3") {
                  boardPresentation = BoardPresentation(boardID: id, input: BoardInput(board))
                }
                Button(
                  "Дочерняя доска с фильтром", systemImage: "line.3.horizontal.decrease.circle"
                ) {
                  boardPresentation = BoardPresentation(input: BoardInput(parentID: id))
                }
              }
              Button("Настройки", systemImage: "gearshape") { showSettings = true }
            } label: {
              Label("Действия", systemImage: "ellipsis.circle")
            }
          }
        }
      }
    }
    #if os(iOS)
      .simultaneousGesture(
        SpatialTapGesture(coordinateSpace: .global).onEnded { event in
          NotificationCenter.default.post(name: .quickTaskOutsideTap, object: event.location)
        })
    #endif
    .tint(Color.accent)
    .sheet(item: $taskPresentation) { TaskEditor(model: model, presentation: $0) }
    .sheet(item: $boardPresentation) { BoardEditor(model: model, presentation: $0) }
    .sheet(item: $listPresentation) { ListEditor(model: model, presentation: $0) }
    .sheet(isPresented: $showSettings) { SettingsView(model: model) }
    .alert(
      "Не удалось выполнить действие",
      isPresented: Binding(
        get: { model.errorMessage != nil && model.hasLoaded },
        set: { if !$0 { model.errorMessage = nil } })
    ) {
      Button("Понятно") { model.errorMessage = nil }
    } message: {
      Text(model.errorMessage ?? "")
    }
    #if os(macOS)
      .onChange(of: model.alertScheduler.ringing.count) { _, count in
        if count > 0 { openWindow(id: "task-alarm") }
      }
    #endif
    .onChange(of: scenePhase) { _, value in
      if value == .active && model.hasLoaded { Task { await model.refreshReminders() } }
    }
    .onOpenURL { url in
      guard url.scheme == "lockedin", url.host == "task",
        let id = UUID(uuidString: url.lastPathComponent)
      else { return }
      Task {
        await model.start()
        if let task = model.snapshot.tasks.first(where: { $0.id == id }) {
          taskPresentation = TaskPresentation(taskID: id, input: TaskInput(task))
        }
      }
    }
    .task {
      await model.start()
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(30)) } catch { break }
        await model.refresh()
      }
    }
  }
  private var sidebar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        Image(systemName: "scope").font(.title2).foregroundStyle(Color.accent)
        VStack(alignment: .leading, spacing: 2) {
          Text("Locked In").font(.headline)
          Text("Make room for your life.").font(.caption2).foregroundStyle(.secondary)
        }
        Spacer()
      }.padding(18)
      List(selection: $destination) {
        Section("Пространство") {
          ForEach([Destination.today, .inbox, .all, .calendar, .board], id: \.self) { route in
            NavigationLink(value: route) {
              Label(route.title(in: model.snapshot), systemImage: route.symbol)
            }
          }
        }
        Section {
          ForEach(flatBoards, id: \.board.id) { entry in
            NavigationLink(value: Destination.boardDetail(entry.board.id)) {
              HStack(spacing: 9) {
                Image(
                  systemName: entry.board.parentID == nil
                    ? "rectangle.stack" : "line.3.horizontal.decrease.circle"
                ).foregroundStyle(Color.accent)
                Text(entry.board.name).lineLimit(1)
                Spacer(minLength: 2)
                Text(
                  "\(TrackerRules.tasks(on:entry.board.id,snapshot:model.snapshot).filter{!$0.completed}.count)"
                ).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
              }.padding(.leading, CGFloat(min(entry.depth, 4)) * 10)
            }.contextMenu {
              Button("Настроить доску") {
                boardPresentation = BoardPresentation(
                  boardID: entry.board.id, input: BoardInput(entry.board))
              }
              Button("Дочерняя доска с фильтром") {
                boardPresentation = BoardPresentation(input: BoardInput(parentID: entry.board.id))
              }
            }
          }
          Button {
            boardPresentation = BoardPresentation()
          } label: {
            Label("Новая доска", systemImage: "plus")
          }.disabled(!model.canEdit)
        } header: {
          Text("Мои доски")
        }
        Section {
          NavigationLink(value: Destination.tags) { Label("Теги", systemImage: "number") }
          NavigationLink(value: Destination.completed) {
            Label("Завершённые", systemImage: "checkmark.circle")
          }
        }
      }.listStyle(.sidebar)
      HStack {
        Circle().fill(model.isOffline ? Color.orange : Color.green).frame(width: 6, height: 6)
        Text(model.settings.mode == .local ? "На этом устройстве" : "Сервер")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button {
          showSettings = true
        } label: {
          Image(systemName: "gearshape")
        }.buttonStyle(.plain).accessibilityLabel("Настройки")
      }.padding(16)
    }.navigationTitle("Locked In")
  }
  @ViewBuilder private var content: some View {
    if !model.hasLoaded {
      if model.isLoading {
        ProgressView("Загружаем пространство…").frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        VStack(spacing: 16) {
          EmptyState(
            symbol: "network", title: "Подключимся к твоим планам",
            message: model.errorMessage ?? "Выбери, где хранить задачи.")
          HStack {
            Button("Повторить") { Task { await model.refresh() } }.buttonStyle(.bordered)
            Button("Настроить подключение") { showSettings = true }.buttonStyle(.borderedProminent)
          }.padding(.bottom, 44)
        }
      }
    } else {
      switch destination ?? .calendar {
      case .calendar:
        CalendarScreen(
          model: model, search: search, showCompleted: showCompleted, open: openTask,
          create: { date in
            taskPresentation = TaskPresentation(
              input: TaskInput(plannedAt: date, durationMinutes: 60))
          })
      case .board, .boardDetail:
        if let id = currentBoardID {
          BoardScreen(
            model: model, boardID: id, search: search, showCompleted: showCompleted, open: openTask,
            create: { listID in
              var input = TaskInput(listID: listID)
              if let selection = TrackerRules.selection(for: id, snapshot: model.snapshot) {
                input.tagIDs = Array(selection.tagIDs)
              }
              taskPresentation = TaskPresentation(input: input)
            }, createList: { newList() },
            editList: { list in
              listPresentation = ListPresentation(listID: list.id, input: ListInput(list))
            },
            editBoard: {
              if let board = model.snapshot.boards.first(where: { $0.id == id }) {
                boardPresentation = BoardPresentation(boardID: id, input: BoardInput(board))
              }
            }
          ).id(id)
        } else {
          EmptyState(
            symbol: "rectangle.stack", title: "Доска недоступна",
            message: "Возможно, она была удалена. Выбери другую доску в меню.")
        }
      case .tags:
        TagsScreen(model: model, select: { destination = .tag($0) })
      default:
        TaskListScreen(
          model: model, destination: destination ?? .all, search: search,
          showCompleted: showCompleted,
          open: openTask, create: { addTask() })
      }
    }
  }
  private func openTask(_ task: TaskRecord) {
    taskPresentation = TaskPresentation(taskID: task.id, input: TaskInput(task))
  }
  private func addTask() {
    var input = TaskInput()
    if case .list(let id) = destination { input.listID = id }
    if let id = currentBoardID,
      let selection = TrackerRules.selection(for: id, snapshot: model.snapshot)
    {
      input.tagIDs = Array(selection.tagIDs)
    }
    if case .tag(let id) = destination { input.tagIDs = [id] }
    taskPresentation = TaskPresentation(input: input)
  }
  private var currentBoardID: UUID? {
    switch destination ?? .board {
    case .board: return model.snapshot.generalBoard?.id
    case .boardDetail(let id): return id
    default: return nil
    }
  }
  private func newList() {
    let boardID =
      currentBoardID.flatMap { TrackerRules.selection(for: $0, snapshot: model.snapshot)?.rootID }
      ?? model.snapshot.generalBoard?.id
    listPresentation = ListPresentation(input: ListInput(boardID: boardID))
  }
  private struct BoardEntry {
    var board: BoardRecord
    var depth: Int
  }
  private var flatBoards: [BoardEntry] {
    var result: [BoardEntry] = []
    var seen = Set<UUID>()
    func append(_ board: BoardRecord, depth: Int) {
      guard seen.insert(board.id).inserted else { return }
      result.append(BoardEntry(board: board, depth: depth))
      for child in model.snapshot.boards.filter({ $0.parentID == board.id }).sorted(by: {
        $0.createdAt < $1.createdAt
      }) { append(child, depth: depth + 1) }
    }
    for board in model.snapshot.boards.filter({
      !$0.isGeneral && ($0.parentID == nil || $0.parentID == model.snapshot.generalBoard?.id)
    }).sorted(by: { $0.createdAt < $1.createdAt }) { append(board, depth: 0) }
    return result
  }
}
