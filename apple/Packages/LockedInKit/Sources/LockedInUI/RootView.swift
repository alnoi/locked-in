import LockedInData
import LockedInDomain
import SwiftUI
#if os(macOS)
import AppKit
#endif

public struct LockedInRootView: View {
  #if os(macOS)
    @Environment(\.openWindow) private var openWindow
  #endif
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  @Bindable private var model: AppModel
  @State private var destination: Destination? = .board
  @State private var navigationHistory = NavigationHistory(initial: Destination.board)
  @State private var hoverSidebar = false
  @State private var columnVisibility = NavigationSplitViewVisibility.all
  @State private var compactColumn = NavigationSplitViewColumn.detail
  @State private var search = ""
  @State private var searchPresented = false
  @State private var taskSheetActive = false
  @State private var pendingShortcut: AppShortcut?
  @State private var taskPresentation: TaskPresentation?
  @State private var boardPresentation: BoardPresentation?
  @State private var listPresentation: ListPresentation?
  @AppStorage(AppTheme.preferenceKey) private var theme: AppTheme = .system
  @AppStorage("trackit.sidebar.collapsedBoards") private var collapsedBoardsStorage = ""
  @State private var showSettings = false
  @State private var showCompleted = false
  public init(model: AppModel) { self.model = model }
  public var body: some View {
    PlannerSidebarLayout(columnVisibility: $columnVisibility, compactColumn: $compactColumn, hoverSidebar: hoverSidebar)
    {
      sidebar
        #if os(macOS)
        .toolbar(removing: .sidebarToggle)
        .background {
          BoardSidebarBoundary(enabled: columnVisibility != .detailOnly || hoverSidebar).allowsHitTesting(false)
        }
        #endif
        .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
    } detail: {
      NavigationStack {
        VStack(spacing: 0) {
          if model.isOffline && model.hasLoaded {
            HStack {
              Image(systemName: "wifi.slash")
              Text("Нет связи · задачи сохраняются на устройстве и отправятся позже")
              Spacer()
              Button("Повторить") { Task { await model.refresh() } }
            }.font(.caption).padding(10).background(.orange.opacity(0.1))
          }
          if let warning = model.syncWarning {
            HStack {
              Image(systemName: "flag.fill").foregroundStyle(.red)
              Text(model.unsyncedTaskIDs.isEmpty ? warning : "Не все изменения отправлены: " + warning)
              Spacer()
              Button("Повторить") { Task { await model.refresh() } }
            }.font(.caption).padding(10).background(.red.opacity(0.08))
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
        .overlay {
          if let token = model.dayProgress.celebrationID {
            DayCompletionCelebration(token: token) {
              withAnimation(.easeOut(duration: 0.2)) {
                if model.dayProgress.celebrationID == token { model.dayProgress.celebrationID = nil }
              }
            }.transition(.opacity.combined(with: .scale(scale: 0.96)))
          }
        }
        .animation(.easeOut(duration: 0.2), value: model.dayProgress.celebrationID)
        .navigationTitle((destination ?? .calendar).title(in: model.snapshot))
        #if os(iOS)
          .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $search, isPresented: $searchPresented, prompt: "Найти задачу")
        #if os(macOS)
        .toolbar(removing: .sidebarToggle)
        #endif
        .toolbar {
          ToolbarItemGroup(placement: .primaryAction) {
            if model.isLoading { ProgressView().controlSize(.small) }
            Button {
              Task { await model.refresh() }
            } label: {
              Label("Обновить", systemImage: "arrow.clockwise")
            }
            .disabled(model.isLoading).keyboardShortcut(
              "r", modifiers: .command)
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
    #if os(macOS)
    .background {
      SidebarHoverTracker(enabled: columnVisibility == .detailOnly, shown: hoverSidebar) { shown in
        withAnimation(.easeInOut(duration: 0.14)) { hoverSidebar = shown }
      }.allowsHitTesting(false)
    }
    .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
      navigationHistory.finishSwitching()
    }
    .onChange(of: destination) { _, value in
      if let value { navigationHistory.visit(value) }
      withAnimation(.easeInOut(duration: 0.14)) { hoverSidebar = false }
    }
    #endif
    #if os(iOS)
      .simultaneousGesture(
        SpatialTapGesture(coordinateSpace: .global).onEnded { event in
          NotificationCenter.default.post(name: .quickTaskOutsideTap, object: event.location)
        })
    #endif
    .background { SearchOutsideClick().allowsHitTesting(false) }
    .background {
      AppShortcutHandler(enabled: taskPresentation == nil && boardPresentation == nil && listPresentation == nil && !showSettings,
        handle: handleShortcut).allowsHitTesting(false)
    }
    .onChange(of: theme) { _, _ in model.publishWidgets() }
    .onChange(of: destination) { _, value in
      model.dayProgress.setOverdueVisible(value == .overdue && scenePhase == .active)
    }
    .onChange(of: destination) { _, value in
      if case .boardDetail(let id) = value {
        saveCollapsedBoards(collapsedBoardIDs.subtracting(boardTree.ancestors(of: id)))
      }
    }
    .onChange(of: model.calendarFocus?.id) { _, _ in
      guard let focus = model.calendarFocus else { return }
      if model.snapshot.tasks.first(where: { $0.id == focus.taskID })?.completed == true { showCompleted = true }
      destination = .calendar
    }
    .onReceive(NotificationCenter.default.publisher(for: .appShortcut)) { notification in
      guard let shortcut = notification.object as? AppShortcut else { return }
      if shortcut == .undo { model.undoLastAction() }
      else if shortcut == .finishSectionSwitch { navigationHistory.finishSwitching() }
      else if taskSheetActive && shortcut != .sidebar { pendingShortcut = shortcut }
      else { _ = handleShortcut(shortcut) }
    }
    .tint(Color.accent)
    .sheet(item: $taskPresentation, onDismiss: {
      taskSheetActive = false
      if let shortcut = pendingShortcut {
        pendingShortcut = nil
        _ = handleShortcut(shortcut)
      }
    }) {
      TaskEditor(model: model, presentation: $0, saveOnOutside: destination == .calendar)
        .onAppear { taskSheetActive = true }
    }
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
      model.dayProgress.setOverdueVisible(destination == .overdue && value == .active)
      if value == .active && model.hasLoaded { Task { await model.refresh(); await model.refreshReminders() } }
      if value == .background { model.publishWidgets(forceReload: true) }
    }
    .onOpenURL { url in
      guard url.scheme == "lockedin" else { return }
      Task {
        await model.start()
        if url.host == "task", let id = UUID(uuidString: url.lastPathComponent),
          let task = model.snapshot.tasks.first(where: { $0.id == id }) {
          let date = task.plannedAt ?? task.deadlineAt
            ?? task.deadlineDate.flatMap(DateOnly.parse) ?? .now
          search = ""
          model.calendarFocus = CalendarTaskFocus(taskID: id, date: date)
          destination = .calendar
          taskPresentation = TaskPresentation(taskID: id, input: TaskInput(task))
        } else if url.host == "calendar",
          let day = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "date" })?.value,
          let date = DateOnly.parse(day) {
          model.calendarFocus = CalendarTaskFocus(date: date)
          destination = .calendar
        } else if url.host == "today" { destination = .today }
      }
    }
    .task {
      await model.start()
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(model.isOffline || !model.unsyncedTaskIDs.isEmpty ? 5 : 30)) } catch { break }
        await model.refresh()
      }
    }
  }
  @ViewBuilder private func sidebarLink<Label: View>(_ route: Destination,
    @ViewBuilder label: () -> Label) -> some View {
    #if os(macOS)
    Button { destination = route } label: { label().frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle()) }
      .buttonStyle(.plain).tag(route)
    #else
    NavigationLink(value: route, label: label)
    #endif
  }
  private var sidebar: some View {
    VStack(spacing: 0) {
      HStack(spacing: 10) {
        #if os(macOS)
        Button {
          toggleSidebar()
        } label: { Image(systemName: "sidebar.left").font(.system(size: 17)) }
        .buttonStyle(.plain)
        .help(columnVisibility == .detailOnly ? "Закрепить боковую панель" : "Скрыть боковую панель")
        .accessibilityLabel(columnVisibility == .detailOnly ? "Закрепить боковую панель" : "Скрыть боковую панель")
        #endif
        Spacer(minLength: 0)
        VStack(alignment: .trailing, spacing: 2) {
          Text("TrackIt").font(.headline)
          Text("Make room for your life.").font(.caption2).foregroundStyle(.secondary)
        }
        Image(systemName: "scope").font(.title2).foregroundStyle(Color.accent)
      }.padding(18)
      List(selection: $destination) {
        Section("Пространство") {
          ForEach([Destination.today, .inbox, .calendar, .board], id: \.self) { route in
            sidebarLink(route) {
              Label(route.title(in: model.snapshot), systemImage: route.symbol)
            }.contextMenu {
              if route == .board, let id = model.snapshot.generalBoard?.id {
                Button("Добавить дочернюю доску", systemImage: "folder.badge.plus") { newChildBoard(id) }
              }
            }
          }
        }
        Section {
          ForEach(boardTree.entries(collapsed: collapsedBoardIDs)) { entry in
            HStack(spacing: 6) {
              if entry.hasChildren {
                Button {
                  var collapsed = collapsedBoardIDs
                  if !collapsed.insert(entry.id).inserted { collapsed.remove(entry.id) }
                  withAnimation(.easeInOut(duration: 0.14)) { saveCollapsedBoards(collapsed) }
                } label: {
                  Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .rotationEffect(.degrees(collapsedBoardIDs.contains(entry.id) ? 0 : 90))
                    .frame(width: 18, height: 24).contentShape(Rectangle())
                }.buttonStyle(.plain)
                  .help(collapsedBoardIDs.contains(entry.id) ? "Развернуть дочерние доски" : "Свернуть дочерние доски")
                  .accessibilityLabel((collapsedBoardIDs.contains(entry.id) ? "Развернуть " : "Свернуть ") + entry.board.name)
              } else {
                Color.clear.frame(width: 18, height: 1).accessibilityHidden(true)
              }
              sidebarLink(Destination.boardDetail(entry.id)) {
                HStack(spacing: 9) {
                  Image(systemName: entry.board.parentID == nil ? "rectangle.stack" : "line.3.horizontal.decrease.circle")
                    .foregroundStyle(Color.accent)
                  Text(entry.board.name).lineLimit(1)
                  Spacer(minLength: 2)
                  Text("\(TrackerRules.tasks(on: entry.id, snapshot: model.snapshot).filter { !$0.completed }.count)")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
              }
            }
            .padding(.leading, CGFloat(entry.depth) * 14)
            .tag(Destination.boardDetail(entry.id))
            .contextMenu {
              Button("Добавить дочернюю доску", systemImage: "folder.badge.plus") { newChildBoard(entry.id) }
              Button("Настроить доску") {
                boardPresentation = BoardPresentation(boardID: entry.id, input: BoardInput(entry.board))
              }
            }
          }
          Button {
            boardPresentation = BoardPresentation()
          } label: {
            Label("Новая доска", systemImage: "plus")
          }.disabled(!model.canEditCollections)
        } header: {
          Text("Мои доски")
        }
        Section {
          sidebarLink(Destination.tags) { Label("Теги", systemImage: "number") }
          sidebarLink(Destination.overdue) {
            HStack {
              Label("Просроченные", systemImage: "calendar.badge.exclamationmark")
              Spacer(minLength: 8)
              if model.dayProgress.unreadOverdueCount > 0 {
                Text("\(model.dayProgress.unreadOverdueCount)").font(.caption.weight(.semibold)).monospacedDigit()
                  .foregroundStyle(.white).padding(.horizontal, 6).padding(.vertical, 2)
                  .background(Color.red, in: Capsule())
                  .accessibilityLabel("Новых просроченных задач: \(model.dayProgress.unreadOverdueCount)")
              }
            }
          }
          sidebarLink(Destination.completed) {
            Label("Завершённые", systemImage: "checkmark.circle")
          }
        }
      }.listStyle(.sidebar).scrollContentBackground(.hidden)
      HStack {
        Circle().fill(model.isOffline ? Color.orange : Color.green).frame(width: 6, height: 6)
        Text(model.settings.mode == .local ? "На этом устройстве" : "Сервер")
          .font(.caption).foregroundStyle(.secondary)
        Spacer()
        Button {
          switch theme {
          case .light: theme = .dark
          case .dark: theme = .system
          case .system: theme = .light
          }
        } label: {
          Image(systemName: theme.symbol)
        }.buttonStyle(.plain)
          .help("Тема: " + theme.title).accessibilityLabel("Тема: " + theme.title)
        Button {
          showSettings = true
        } label: {
          Image(systemName: "gearshape")
        }.buttonStyle(.plain).accessibilityLabel("Настройки")
      }.padding(16)
    }.navigationTitle("TrackIt")
  }
  @ViewBuilder private var content: some View {
    if !model.hasLoaded {
      if model.isLoading {
        ProgressView("Загружаем пространство…").frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        VStack(spacing: 16) {
          EmptyState(
            symbol: "network", title: "Подключимся к твоим планам",
            message: model.syncWarning ?? model.errorMessage ?? "Выбери, где хранить задачи.")
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
          model: model, search: search, showCompleted: showCompleted, focus: model.calendarFocus, open: openTask,
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
  private func handleShortcut(_ shortcut: AppShortcut) -> Bool {
    switch shortcut {
    case .undo:
      model.undoLastAction()
      return true
    case .search:
      searchPresented = false
      DispatchQueue.main.async { searchPresented = true }
      return true
    case .newInboxTask:
      guard model.canEdit else { return true }
      taskPresentation = TaskPresentation(input: TaskInput())
      return true
    case .sidebar:
      toggleSidebar()
      return true
    case .previousSection:
      if let previous = navigationHistory.previous() { destination = previous }
      #if os(macOS)
      if !NSEvent.modifierFlags.contains(.control) { navigationHistory.finishSwitching() }
      #endif
      return true
    case .finishSectionSwitch:
      navigationHistory.finishSwitching()
      return true
    default: return false
    }
  }
  private func toggleSidebar() {
    withAnimation(.easeInOut(duration: 0.14)) {
      columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
      hoverSidebar = false
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
  private var boardTree: BoardSidebarTree { BoardSidebarTree(boards: model.snapshot.boards) }
  private var collapsedBoardIDs: Set<UUID> {
    Set(collapsedBoardsStorage.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
  }
  private func saveCollapsedBoards(_ ids: Set<UUID>) {
    collapsedBoardsStorage = ids.map(\.uuidString).sorted().joined(separator: ",")
  }
  private func newChildBoard(_ id: UUID) {
    saveCollapsedBoards(collapsedBoardIDs.subtracting(boardTree.ancestors(of: id).union([id])))
    boardPresentation = BoardPresentation(input: BoardInput(parentID: id))
  }
}
