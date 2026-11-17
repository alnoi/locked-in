import LockedInDomain
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class BoardReorderSession {
  private(set) var source: UUID?
  private(set) var hoveredListID: UUID?
  private(set) var order: [UUID] = []
  enum Kind { case list, task }
  private let kind: Kind
  init(kind: Kind = .list) { self.kind = kind }
  private var token: UUID?
  private var pendingHover: Task<Void, Never>?
  private var hoverTarget: UUID?
  private var finishing = false
  var projectTarget: UUID?
  struct Placement: Equatable {
    var parentID: UUID?
    var listID: UUID?
    var target: UUID
    var after: Bool
  }
  private(set) var placement: Placement?
  private var pendingPlacement: Placement?
  func preview(_ value: Placement) {
    guard !finishing, let source, value.target != source || value.parentID == nil else { return }
    guard pendingPlacement != value else { return }
    cancelHover()
    pendingPlacement = value
    let current = token
    pendingHover = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
      guard let self, self.token == current, !Task.isCancelled else { return }
      withAnimation(.snappy(duration: 0.12, extraBounce: 0)) {
        self.placement = value
        self.order.removeAll { $0 == source }
        if let index = self.order.firstIndex(of: value.target) {
          self.order.insert(source, at: index + (value.after ? 1 : 0))
        } else { self.order.append(source) }
      }
    }
  }
  func hoverList(_ listID: UUID?) {
    guard kind == .task, source != nil, !finishing else { return }
    hoveredListID = listID ?? ListOrdering.inboxID
  }
  func previewEnd(listID: UUID?, visibleTasks: [TaskRecord], allTasks: [TaskRecord]) {
    guard let source else { return }
    let positions = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($0.element, $0.offset) })
    let roots = TaskProjectGrouping.roots(visible: visibleTasks, all: allTasks).filter { $0.id != source }
    let lastRoot = roots.max { positions[$0.id, default: -1] < positions[$1.id, default: -1] }
    let members = lastRoot.map { root in
      allTasks.filter { $0.id != source && ($0.id == root.id || $0.parentID == root.id) }
    } ?? []
    let target = members.max { positions[$0.id, default: -1] < positions[$1.id, default: -1] }?.id ?? source
    preview(.init(parentID: nil, listID: listID, target: target, after: true))
  }
  func cancelHover(_ target: UUID? = nil) {
    guard target == nil || hoverTarget == target else { return }
    pendingHover?.cancel()
    pendingHover = nil
    hoverTarget = nil
    projectTarget = nil
    pendingPlacement = nil
  }
  func begin(_ id: UUID, order: [UUID]) -> NSItemProvider {
    cancelHover()
    finishing = false
    placement = nil
    hoveredListID = nil
    let token = UUID()
    self.token = token
    source = id
    self.order = order
    return ListDragProvider(
      text: (kind == .list ? BoardDragPayload.list(id) : BoardDragPayload.task(id)).text
    ) { [weak self] in
      Task { @MainActor in
        guard self?.token == token else { return }
        self?.reset(animated: self?.finishing != true)
      }
    }
  }
  func hover(_ target: UUID) {
    guard !finishing, let source, target != source, order.contains(target) else {
      cancelHover()
      return
    }
    guard hoverTarget != target else { return }
    cancelHover()
    hoverTarget = target
    let current = token
    pendingHover = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
      guard let self, !Task.isCancelled, self.token == current,
        self.hoverTarget == target, !self.finishing else { return }
      withAnimation(.snappy(duration: 0.12, extraBounce: 0)) {
        self.order = ListOrdering.preview(moving: source, over: target, ids: self.order)
      }
    }
  }
  func finishDrop() {
    cancelHover()
    finishing = true
    #if !os(macOS)
      reset()
    #endif
  }
  func reset(animated: Bool = true) {
    cancelHover()
    finishing = false
    let clear = {
      self.placement = nil
      self.source = nil
      self.hoveredListID = nil
      self.order = []
      self.token = nil
    }
    if animated { withAnimation(.snappy(duration: 0.12, extraBounce: 0), clear) }
    else {
      var transaction = Transaction()
      transaction.disablesAnimations = true
      withTransaction(transaction, clear)
    }
  }
}
final class ListDragProvider: NSItemProvider, @unchecked Sendable {
  let text: String
  private let ended: @Sendable () -> Void
  init(text: String, ended: @escaping @Sendable () -> Void) {
    self.text = text
    self.ended = ended
    super.init()
    registerObject(text as NSString, visibility: .ownProcess)
  }
  func finish() { ended() }
  deinit { ended() }
}
struct WholeListDraggable: ViewModifier {
  var listID: UUID?
  var enabled: Bool
  var session: BoardReorderSession
  var order: [UUID]
  func body(content: Content) -> some View {
    if let listID, enabled {
      content.modifier(ReorderDragSource(id: listID, provider: { session.begin(listID, order: order) }))
    } else {
      content
    }
  }
}
struct BoardDropDelegate: DropDelegate {
  var enabled: Bool
  var hover: () -> Void = {}
  var hoverAt: (CGPoint) -> Void = { _ in }
  var unhover: () -> Void = {}
  var localDrop: () -> Bool = { false }
  var accept: @MainActor (BoardDragPayload) -> Void
  var failure: @MainActor (String) -> Void
  func validateDrop(info: DropInfo) -> Bool {
    enabled && info.hasItemsConforming(to: [UTType.text.identifier])
  }
  func dropEntered(info: DropInfo) {
    if enabled { hover(); hoverAt(info.location) }
  }
  func dropExited(info: DropInfo) { unhover() }
  func dropUpdated(info: DropInfo) -> DropProposal? {
    guard enabled else { return nil }
    hover()
    hoverAt(info.location)
    return DropProposal(operation: .move)
  }
  func performDrop(info: DropInfo) -> Bool {
    guard enabled else { return false }
    if localDrop() { return true }
    guard let provider = info.itemProviders(for: [UTType.text.identifier]).first,
      provider.canLoadObject(ofClass: NSString.self)
    else { return false }
    provider.loadObject(ofClass: NSString.self) { object, error in
      Task { @MainActor in
        if error != nil {
          failure("Не удалось прочитать переносимый список. Попробуй ещё раз.")
          return
        }
        guard let text = object as? String, let payload = BoardDragPayload(text: text) else {
          return
        }
        accept(payload)
      }
    }
    return true
  }
}

/// One placement model for siblings, project children and extraction back into a list.
struct TaskPlacementDropDelegate: DropDelegate {
  let model: AppModel
  let target: TaskRecord
  let height: CGFloat
  let projectHeader: Bool
  let session: BoardReorderSession
  var listDrop: BoardDropDelegate?

  private func placement(_ info: DropInfo) -> BoardReorderSession.Placement? {
    guard let source = session.source, source != target.id,
      model.snapshot.tasks.contains(where: { $0.id == source }) else { return nil }
    let hasChildren = model.snapshot.tasks.contains { $0.parentID == source || ($0.id == source && $0.isProject == true) }
    let intoProject = projectHeader && info.location.y > 12
    let parent = intoProject ? target.id : target.parentID
    guard parent != source, !(hasChildren && parent != nil) else { return nil }
    return .init(parentID: parent,
      listID: TaskProjectGrouping.listID(of: target, in: model.snapshot.tasks),
      target: target.id, after: intoProject || info.location.y > height / 2)
  }
  func validateDrop(info: DropInfo) -> Bool {
    if session.source != nil { return placement(info) != nil || session.source == target.id }
    return listDrop?.validateDrop(info: info) ?? false
  }
  func dropEntered(info: DropInfo) { update(info) }
  func dropUpdated(info: DropInfo) -> DropProposal? {
    update(info)
    return validateDrop(info: info) ? DropProposal(operation: .move) : nil
  }
  private func update(_ info: DropInfo) {
    session.hoverList(TaskProjectGrouping.listID(of: target, in: model.snapshot.tasks))
    if let value = placement(info) { session.preview(value) }
    else if session.source == nil { listDrop?.dropEntered(info: info) }
  }
  func dropExited(info: DropInfo) {
    session.cancelHover()
    if session.source == nil { listDrop?.dropExited(info: info) }
  }
  func performDrop(info: DropInfo) -> Bool {
    guard let source = session.source else { return listDrop?.performDrop(info: info) ?? false }
    // Dropping on the displaced source keeps the preview's destination.
    guard let value = session.placement ?? placement(info),
      let task = model.snapshot.tasks.first(where: { $0.id == source }) else { return false }
    var order = session.order.filter { $0 != source }
    if let index = order.firstIndex(of: value.target) {
      order.insert(source, at: index + (value.after ? 1 : 0))
    } else { order.append(source) }
    model.saveTaskOrder(order)
    if task.parentID != value.parentID || task.listID != value.listID {
      var input = TaskInput(task)
      input.parentID = value.parentID
      input.listID = value.listID
      if value.parentID == nil && model.snapshot.tasks.contains(where: { $0.parentID == source }) {
        model.move(source, to: value.listID)
      } else {
        model.perform(.task(task.id, input))
      }
    }
    session.finishDrop()
    return true
  }
}

struct TaskPlacementTarget: ViewModifier {
  let model: AppModel
  let target: TaskRecord
  var projectHeader = false
  let session: BoardReorderSession
  var listDrop: BoardDropDelegate?
  var enabled = true
  @State private var height: CGFloat = 44
  @ViewBuilder func body(content: Content) -> some View {
    if enabled {
    content.background {
      GeometryReader { geometry in
        Color.clear.onAppear { height = geometry.size.height }
          .onChange(of: geometry.size.height) { _, value in height = value }
      }
    }.onDrop(of: [UTType.text.identifier], delegate: TaskPlacementDropDelegate(
      model: model, target: target, height: height, projectHeader: projectHeader,
      session: session, listDrop: listDrop))
    } else { content }
  }
}
