import LockedInData
import LockedInDomain
import SwiftUI
import UniformTypeIdentifiers

struct BoardScreen: View {
  @Bindable var model: AppModel
  let boardID: UUID
  var search: String
  var showCompleted: Bool
  var open: (TaskRecord) -> Void
  var create: (UUID?) -> Void
  var createList: () -> Void
  var editList: (TaskList) -> Void
  var editBoard: () -> Void
  @State private var taskEndPositions: [UUID: CGFloat] = [:]
  @State private var dragSession = BoardReorderSession()
  @State private var taskDragSession = BoardReorderSession(kind: .task)
  @State private var style: BoardDisplayStyle
  init(
    model: AppModel, boardID: UUID, search: String, showCompleted: Bool,
    open: @escaping (TaskRecord) -> Void,
    create: @escaping (UUID?) -> Void, createList: @escaping () -> Void,
    editList: @escaping (TaskList) -> Void,
    editBoard: @escaping () -> Void
  ) {
    self.model = model
    self.boardID = boardID
    self.search = search
    self.showCompleted = showCompleted
    self.open = open
    self.create = create
    self.createList = createList
    self.editList = editList
    self.editBoard = editBoard
    _style = State(
      initialValue: BoardPreferences.style(
        boardID: boardID,
        isGeneral: model.snapshot.boards.first { $0.id == boardID }?.isGeneral == true,
        space: model.settings.identity))
  }
  private var board: BoardRecord? { model.snapshot.boards.first { $0.id == boardID } }
  private var selection: TrackerRules.Selection? {
    TrackerRules.selection(for: boardID, snapshot: model.snapshot)
  }
  private var lists: [TaskList] { TrackerRules.lists(in: boardID, snapshot: model.snapshot) }
  private var listIDs: [UUID] {
    dragSession.source == nil
      ? model.displayListIDs(lists, includeInbox: selection?.rootID == nil) : dragSession.order
  }
  private var tasks: [TaskRecord] {
    TrackerRules.tasks(on: boardID, snapshot: model.snapshot).filter {
      (showCompleted || selection?.completed.contains(true) == true || !$0.completed)
        && (search.isEmpty || $0.title.localizedCaseInsensitiveContains(search))
    }.sorted { $0.createdAt < $1.createdAt }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      header.padding([.horizontal, .top], 20)
      if board?.parentID != nil {
        HStack {
          Image(systemName: "line.3.horizontal.decrease.circle")
          Text("Фильтр задач · списки общие с родительской доской").font(.caption)
          Spacer()
          Button("Изменить фильтр", action: editBoard).font(.caption)
        }.foregroundStyle(.secondary).padding(.horizontal, 20)
      }
      if style == .columns { columns.environment(\.centeredTaskInspector, false) } else { rows }
    }.onChange(of: boardID) { _, _ in
      dragSession.reset(animated: false)
      taskDragSession.reset(animated: false)
      style = BoardPreferences.style(
        boardID: boardID, isGeneral: board?.isGeneral == true, space: model.settings.identity)
    }.onChange(of: style) { _, value in
      dragSession.reset()
      taskDragSession.reset()
      BoardPreferences.save(value, boardID: boardID, space: model.settings.identity)
    }.onDisappear {
      dragSession.reset()
      taskDragSession.reset()
    }
  }
  private func finishListDrag(_ source: UUID, over target: UUID) {
    if dragSession.source == source {
      model.saveListOrder(dragSession.order)
      dragSession.finishDrop()
    } else {
      model.reorderList(source, over: target, visible: listIDs)
    }
  }
  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        VStack(alignment: .leading, spacing: 5) {
          Text(board?.name ?? "Доска").font(.title2.bold())
          Text("\(lists.count) списков · \(tasks.count) задач").font(.subheadline).foregroundStyle(
            .secondary)
        }
        Spacer()
      }
      Picker("Представление", selection: $style) {
        ForEach(BoardDisplayStyle.allCases) { Text($0.title).tag($0) }
      }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 240)
    }
  }
  private var columns: some View {
    ScrollView(.horizontal) {
      HStack(alignment: .taskCardsTop, spacing: 4) {
        ForEach(listIDs, id: \.self) { id in
          let list = lists.first { $0.id == id }
          BoardColumn(
            model: model, title: list?.name ?? "Входящие",
            symbol: list == nil ? "tray" : "list.bullet", listID: list?.id,
            tasks: tasks.filter { TaskProjectGrouping.listID(of: $0, in: model.snapshot.tasks) == list?.id }, open: open, create: { create(list?.id) },
            edit: list.map { value in { editList(value) } },
            dragSession: dragSession, taskDragSession: taskDragSession, order: listIDs,
            requiredTags: Array(selection?.tagIDs ?? []),
            reorder: { source in finishListDrag(source, over: id) }
          )
        }
        Button(action: createList) {
          VStack(spacing: 10) {
            Image(systemName: "plus").font(.title2)
            Text("Добавить список").font(.subheadline)
          }.foregroundStyle(.secondary).frame(width: 210, height: 130).background(
            Color.mutedSurface, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).disabled(!model.canEditCollections)
          .padding(.horizontal, 8)
          .alignmentGuide(.taskCardsTop) { $0[.top] }
      }.padding(.horizontal, 20).padding(.bottom, 20)
    }
    #if os(macOS)
    .scrollClipDisabled()
    #endif
    .modifier(BoardDragAutoscroll(scrollOverSidebar: taskDragSession.source != nil))
  }
  private var rows: some View {
    ScrollViewReader { proxy in
    ScrollView {
      LazyVStack(spacing: 6) {
        ForEach(listIDs, id: \.self) { id in
          let list = lists.first { $0.id == id }
          rowGroup(title: list?.name ?? "Входящие", list: list) {
            withAnimation(.easeOut(duration: 0.1)) {
              proxy.scrollTo(QuickTaskScrollTarget(listID: list?.id), anchor: .bottom)
            }
          }
        }
        Button(action: createList) {
          Label("Добавить список", systemImage: "plus").frame(maxWidth: .infinity).padding(14)
        }.buttonStyle(.bordered).disabled(!model.canEditCollections)
      }
      #if os(iOS)
      .padding(.horizontal, 16).padding(.vertical, 8)
      #else
      .padding(20)
      #endif
    }.refreshable { await model.refresh() }
      .modifier(BoardDragAutoscroll(axis: .vertical, enabled: taskDragSession.source != nil))
    }
  }
  private func rowGroup(title: String, list: TaskList?, revealQuickTask: @escaping () -> Void) -> some View {
    let items = tasks.filter { TaskProjectGrouping.listID(of: $0, in: model.snapshot.tasks) == list?.id }
    let listDrop = BoardDropDelegate(
          enabled: model.hasLoaded,
          hover: { dragSession.hover(list?.id ?? ListOrdering.inboxID) },
          hoverAt: { point in
            taskDragSession.hoverList(list?.id)
            if let bottom = taskEndPositions[list?.id ?? ListOrdering.inboxID], point.y >= bottom {
              taskDragSession.previewEnd(listID: list?.id, visibleTasks: items, allTasks: model.snapshot.tasks)
            }
          },
          unhover: {
            dragSession.cancelHover(list?.id ?? ListOrdering.inboxID)
          },
          localDrop: {
            if let source = taskDragSession.source {
              let task = model.snapshot.tasks.first { $0.id == source }
              model.groupedUndo {
                model.move(source, to: list?.id, includingProject: task?.parentID == nil)
                model.saveTaskOrder(taskDragSession.order.filter { $0 != source } + [source])
              }
              taskDragSession.finishDrop()
              return true
            }
            guard let source = dragSession.source else { return false }
            finishListDrag(source, over: list?.id ?? ListOrdering.inboxID)
            return true
          },
          accept: { payload in
            switch payload {
            case .task(let id): model.move(id, to: list?.id)
            case .list(let id):
              finishListDrag(id, over: list?.id ?? ListOrdering.inboxID)
            }
          }, failure: { model.errorMessage = $0 })
    return VStack(alignment: .leading, spacing: 6) {
      HStack {
        Image(systemName: list == nil ? "tray" : "list.bullet").foregroundStyle(Color.accent)
        Text(title).font(.headline)
        Text("\(items.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        Spacer()
        if let list {
          ListActionsMenu(model: model, listID: list.id, name: list.name, rename: { editList(list) })
        }
        Button {
          create(list?.id)
        } label: {
          Image(systemName: "plus")
        }.buttonStyle(.plain).disabled(!model.canEdit).accessibilityLabel("Добавить в " + title)
      }
      TaskReorderGroup(model: model, tasks: items, session: taskDragSession, open: open, listDrop: listDrop, destinationListID: list?.id)
      QuickTaskCard(model: model, listID: list?.id, requiredTags: Array(selection?.tagIDs ?? []), reveal: revealQuickTask)
        .id(QuickTaskScrollTarget(listID: list?.id))
        .modifier(TaskListEndMarker(space: list?.id ?? ListOrdering.inboxID) { position in
          taskEndPositions[list?.id ?? ListOrdering.inboxID] = position
        })
    }
      #if os(macOS)
      .padding(.horizontal, 16)
      #endif
      .padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
      .modifier(
        WholeListDraggable(
          listID: list?.id ?? ListOrdering.inboxID, enabled: model.hasLoaded, session: dragSession,
          order: listIDs)
      )
      .modifier(ReorderSourceAppearance(active: dragSession.source == (list?.id ?? ListOrdering.inboxID)))
      .coordinateSpace(name: list?.id ?? ListOrdering.inboxID)
      .onDrop(
        of: [UTType.text.identifier],
        delegate: listDrop)
  }
}
private struct BoardColumn: View {
  @State private var taskEndPosition = CGFloat.infinity
  @Bindable var model: AppModel
  var title: String
  var symbol: String
  var listID: UUID?
  var tasks: [TaskRecord]
  var open: (TaskRecord) -> Void
  var create: () -> Void
  var edit: (() -> Void)?
  var dragSession: BoardReorderSession
  var taskDragSession: BoardReorderSession
  var order: [UUID]
  var requiredTags: [UUID]
  var reorder: (UUID) -> Void
  private var listDrop: BoardDropDelegate {
    BoardDropDelegate(
        enabled: model.hasLoaded,
        hover: { dragSession.hover(listID ?? ListOrdering.inboxID) },
        hoverAt: { point in
          taskDragSession.hoverList(listID)
          if point.y >= taskEndPosition {
            taskDragSession.previewEnd(listID: listID, visibleTasks: tasks, allTasks: model.snapshot.tasks)
          }
        },
        unhover: {
          dragSession.cancelHover(listID ?? ListOrdering.inboxID)
        },
        localDrop: {
          if let source = taskDragSession.source {
            let task = model.snapshot.tasks.first { $0.id == source }
            model.groupedUndo {
              model.move(source, to: listID, includingProject: task?.parentID == nil)
              model.saveTaskOrder(taskDragSession.order.filter { $0 != source } + [source])
            }
            taskDragSession.finishDrop()
            return true
          }
          guard let source = dragSession.source else { return false }
          reorder(source)
          return true
        },
        accept: { payload in
          switch payload {
          case .task(let id): model.move(id, to: listID)
          case .list(let id): reorder(id)
          }
        }, failure: { model.errorMessage = $0 })
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title).font(.title3.bold()).lineLimit(1)
        Text("\(tasks.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
        Spacer(minLength: 0)
        if let listID, let edit {
          ListActionsMenu(model: model, listID: listID, name: title, rename: edit)
        }
        Button(action: create) { Image(systemName: "plus") }.buttonStyle(.plain).disabled(
          !model.canEdit
        )
        .accessibilityLabel("Добавить в " + title)
      }.padding(.horizontal, 4)
        .background {
          #if os(macOS)
          BoardScrollHeaderBoundary(id: listID ?? ListOrdering.inboxID).allowsHitTesting(false)
          #endif
        }
      ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 6) {
          TaskReorderGroup(model: model, tasks: tasks, session: taskDragSession, open: open, listDrop: listDrop, destinationListID: listID)
          QuickTaskCard(model: model, listID: listID, requiredTags: requiredTags) {
            withAnimation(.easeOut(duration: 0.1)) {
              proxy.scrollTo(QuickTaskScrollTarget(listID: listID), anchor: .bottom)
            }
          }
            .id(QuickTaskScrollTarget(listID: listID))
            .modifier(TaskListEndMarker(space: listID ?? ListOrdering.inboxID) { taskEndPosition = $0 })
        }.padding(2)
      }.modifier(BoardDragAutoscroll(axis: .vertical,
          enabled: taskDragSession.source != nil && taskDragSession.hoveredListID == (listID ?? ListOrdering.inboxID),
          headerID: listID ?? ListOrdering.inboxID))
      }
        .alignmentGuide(.taskCardsTop) { $0[.top] + 2 }
    }.padding(.horizontal, 6).padding(.vertical, 10).frame(width: 242).frame(
      maxHeight: .infinity, alignment: .top
    )
    .modifier(
      WholeListDraggable(
        listID: listID ?? ListOrdering.inboxID, enabled: model.hasLoaded, session: dragSession,
        order: order)
    )
    .modifier(ReorderSourceAppearance(active: dragSession.source == (listID ?? ListOrdering.inboxID)))
    .coordinateSpace(name: listID ?? ListOrdering.inboxID)
    .onDrop(
      of: [UTType.text.identifier],
      delegate: listDrop)
  }
}

extension VerticalAlignment {
  private enum TaskCardsTop: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat { context[.top] }
  }
  fileprivate static let taskCardsTop = VerticalAlignment(TaskCardsTop.self)
}

private struct ListActionsMenu: View {
  @Bindable var model: AppModel
  var listID: UUID
  var name: String
  var rename: () -> Void
  @State private var confirmDelete = false
  var body: some View {
    Menu {
      Button("Изменить", systemImage: "pencil", action: rename)
      Button("Удалить список", systemImage: "trash", role: .destructive) { confirmDelete = true }
    } label: {
      Image(systemName: "ellipsis").frame(width: 24, height: 24).contentShape(Rectangle())
    }
    .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    .disabled(!model.canEditCollections).accessibilityLabel("Действия со списком " + name)
    .confirmationDialog("Удалить список «" + name + "»?", isPresented: $confirmDelete, titleVisibility: .visible) {
      Button("Удалить список", role: .destructive) { model.perform(.deleteList(listID)) }
      Button("Отмена", role: .cancel) {}
    } message: {
      Text("Все задачи списка будут перемещены во «Входящие».")
    }
  }
}
