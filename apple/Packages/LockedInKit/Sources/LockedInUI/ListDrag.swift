import LockedInDomain
import Observation
import SwiftUI
import UniformTypeIdentifiers

@MainActor @Observable
final class BoardReorderSession {
  private(set) var source: UUID?
  private(set) var order: [UUID] = []
  enum Kind { case list, task }
  private let kind: Kind
  init(kind: Kind = .list) { self.kind = kind }
  private var token: UUID?
  private var pendingHover: Task<Void, Never>?
  private var hoverTarget: UUID?
  private var finishing = false
  func cancelHover(_ target: UUID? = nil) {
    guard target == nil || hoverTarget == target else { return }
    pendingHover?.cancel()
    pendingHover = nil
    hoverTarget = nil
  }
  func begin(_ id: UUID, order: [UUID]) -> NSItemProvider {
    cancelHover()
    finishing = false
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
      do { try await Task.sleep(for: .milliseconds(260)) } catch { return }
      guard let self, !Task.isCancelled, self.token == current,
        self.hoverTarget == target, !self.finishing else { return }
      withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
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
      self.source = nil
      self.order = []
      self.token = nil
    }
    if animated { withAnimation(.spring(response: 0.3, dampingFraction: 0.85), clear) }
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
  var unhover: () -> Void = {}
  var localDrop: () -> Bool = { false }
  var accept: @MainActor (BoardDragPayload) -> Void
  var failure: @MainActor (String) -> Void
  func validateDrop(info: DropInfo) -> Bool {
    enabled && info.hasItemsConforming(to: [UTType.text.identifier])
  }
  func dropEntered(info: DropInfo) {
    if enabled { hover() }
  }
  func dropExited(info: DropInfo) { unhover() }
  func dropUpdated(info: DropInfo) -> DropProposal? {
    guard enabled else { return nil }
    hover()
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

struct TaskReorderDropDelegate: DropDelegate {
  let target: UUID
  let session: BoardReorderSession
  var commit: ([UUID]) -> Void
  var listDrop: BoardDropDelegate? = nil
  private var reordersTask: Bool { session.source != nil && session.order.contains(target) }
  func validateDrop(info: DropInfo) -> Bool {
    if reordersTask { return info.hasItemsConforming(to: [UTType.text.identifier]) }
    return listDrop?.validateDrop(info: info) ?? false
  }
  func dropEntered(info: DropInfo) {
    if reordersTask { session.hover(target) }
    else { listDrop?.dropEntered(info: info) }
  }
  func dropExited(info: DropInfo) {
    if reordersTask { session.cancelHover(target) }
    else { listDrop?.dropExited(info: info) }
  }
  func dropUpdated(info: DropInfo) -> DropProposal? {
    if reordersTask {
      session.hover(target)
      return DropProposal(operation: .move)
    }
    return listDrop?.dropUpdated(info: info)
  }
  func performDrop(info: DropInfo) -> Bool {
    guard validateDrop(info: info) else { return false }
    if !reordersTask { return listDrop?.performDrop(info: info) ?? false }
    commit(session.order)
    session.finishDrop()
    return true
  }
}
