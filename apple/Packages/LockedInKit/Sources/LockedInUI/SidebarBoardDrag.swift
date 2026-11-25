import LockedInDomain
import Observation
import SwiftUI

struct SidebarBoardPlacement: Equatable {
  var target: UUID
  var after: Bool
  func applying(source: UUID, to current: [UUID]) -> [UUID] {
    guard source != target, current.contains(source), current.contains(target) else { return current }
    var result = current.filter { $0 != source }
    guard let index = result.firstIndex(of: target) else { return current }
    result.insert(source, at: index + (after ? 1 : 0))
    return result
  }
}

@MainActor @Observable
final class SidebarBoardDragSession {
  static let typeIdentifier = "com.alan.planner.sidebar-board"
  private(set) var source: UUID?
  private(set) var order: [UUID] = []
  private var token: UUID?
  private var pendingHover: Task<Void, Never>?
  private var hoverTarget: SidebarBoardPlacement?
  private var previewedTarget: SidebarBoardPlacement?
  private var finishing = false

  func begin(_ id: UUID, order: [UUID]) -> NSItemProvider {
    reset(animated: false)
    let token = UUID()
    self.token = token
    source = id
    self.order = order
    return ListDragProvider(text: id.uuidString, typeIdentifier: Self.typeIdentifier) { [weak self] in
      Task { @MainActor in
        guard self?.token == token else { return }
        self?.reset(animated: self?.finishing != true)
      }
    }
  }
  func placement(on id: UUID, y: CGFloat, height: CGFloat,
    tree: BoardSidebarTree) -> SidebarBoardPlacement? {
    guard let source, let target = tree.reorderTarget(source: source, hovered: id) else { return nil }
    if target == source { return previewedTarget ?? SidebarBoardPlacement(target: source, after: false) }
    return SidebarBoardPlacement(target: target, after: target != id || y >= height / 2)
  }
  func hover(_ target: SidebarBoardPlacement) {
    guard !finishing, let source, target.target != source else { cancelHover(); return }
    guard target != hoverTarget else { return }
    cancelHover()
    guard target != previewedTarget else { return }
    hoverTarget = target
    let token = token
    pendingHover = Task { @MainActor [weak self] in
      do { try await Task.sleep(for: .milliseconds(90)) } catch { return }
      guard let self, self.token == token, !Task.isCancelled, self.hoverTarget == target else { return }
      withAnimation(.snappy(duration: 0.12, extraBounce: 0)) {
        self.order = target.applying(source: source, to: self.order)
        self.previewedTarget = target
      }
    }
  }
  func cancelHover() {
    pendingHover?.cancel(); pendingHover = nil; hoverTarget = nil
  }
  func commit(_ target: SidebarBoardPlacement) -> [UUID] {
    cancelHover()
    if let source { order = target.applying(source: source, to: order) }
    return order
  }
  func finish() {
    finishing = true
    #if !os(macOS)
    reset(animated: false)
    #endif
  }
  func reset(animated: Bool = true) {
    cancelHover()
    let clear = {
      self.source = nil; self.order = []; self.token = nil
      self.previewedTarget = nil; self.finishing = false
    }
    if animated { withAnimation(.snappy(duration: 0.12, extraBounce: 0), clear) } else { clear() }
  }
}

struct SidebarBoardReorder: ViewModifier {
  var id: UUID
  var tree: BoardSidebarTree
  var order: [UUID]
  var session: SidebarBoardDragSession
  var save: ([UUID]) -> Void
  @State private var height: CGFloat = 28
  func body(content: Content) -> some View {
    content.padding(.vertical, 4).contentShape(Rectangle())
      .background {
        GeometryReader { geometry in
          Color.clear.allowsHitTesting(false)
            .onGeometryChange(for: CGFloat.self) { _ in geometry.size.height } action: { height = $0 }
        }
      }
      .modifier(ReorderDragSource(id: id, provider: { session.begin(id, order: order) }))
      .modifier(ReorderSourceAppearance(active: session.source.map {
        $0 == id || tree.ancestors(of: id).contains($0)
      } ?? false))
      .onDrop(of: [SidebarBoardDragSession.typeIdentifier], delegate: SidebarBoardDropDelegate(
        id: id, height: height, tree: tree, session: session, save: save))
      #if os(macOS)
      .background { SidebarBoardDropFeedback().allowsHitTesting(false) }
      #endif
  }
}

#if os(macOS)
import AppKit

private struct SidebarBoardDropFeedback: NSViewRepresentable {
  func makeNSView(context: Context) -> SidebarBoardDropFeedbackView { SidebarBoardDropFeedbackView() }
  func updateNSView(_ view: SidebarBoardDropFeedbackView, context: Context) {
    view.suppressFeedback()
    DispatchQueue.main.async { [weak view] in view?.suppressFeedback() }
  }
}
private final class SidebarBoardDropFeedbackView: NSView {
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToSuperview() { super.viewDidMoveToSuperview(); suppressFeedback() }
  override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); suppressFeedback() }
  func suppressFeedback() {
    var ancestor = superview
    while let view = ancestor {
      if let table = view as? NSTableView {
        // Keep normal selection; only replace the system's blue drop highlight with our animated gap.
        table.draggingDestinationFeedbackStyle = .none
        return
      }
      ancestor = view.superview
    }
  }
}
#endif

private struct SidebarBoardDropDelegate: DropDelegate {
  var id: UUID
  var height: CGFloat
  var tree: BoardSidebarTree
  var session: SidebarBoardDragSession
  var save: ([UUID]) -> Void
  private func placement(_ info: DropInfo) -> SidebarBoardPlacement? {
    session.placement(on: id, y: info.location.y, height: height, tree: tree)
  }
  func validateDrop(info: DropInfo) -> Bool { placement(info) != nil }
  func dropEntered(info: DropInfo) { if let target = placement(info) { session.hover(target) } }
  func dropUpdated(info: DropInfo) -> DropProposal? {
    guard let target = placement(info) else { session.cancelHover(); return DropProposal(operation: .forbidden) }
    session.hover(target)
    return DropProposal(operation: .move)
  }
  func dropExited(info: DropInfo) { session.cancelHover() }
  func performDrop(info: DropInfo) -> Bool {
    guard let target = placement(info) else { return false }
    save(session.commit(target))
    session.finish()
    return true
  }
}
