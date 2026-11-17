import SwiftUI

struct BoardDragAutoscroll: ViewModifier {
  var axis: Axis = .horizontal
  var enabled = true
  var headerID: UUID?
  var scrollOverSidebar = false
  @ViewBuilder func body(content: Content) -> some View {
    #if os(macOS)
    if #available(macOS 15, *) {
      content.modifier(BoardScrollPosition(axis: axis, enabled: enabled, headerID: headerID, scrollOverSidebar: scrollOverSidebar))
    } else { content }
    #else
    content
    #endif
  }
}

#if os(macOS)
import AppKit

@available(macOS 15, *)
private struct BoardScrollPosition: ViewModifier {
  var axis: Axis
  var enabled: Bool
  var headerID: UUID?
  var scrollOverSidebar: Bool
  @State private var position = ScrollPosition(x: 0)
  @State private var offset: CGFloat = 0
  @State private var maximum: CGFloat = 0
  @State private var motion = BoardAutoscrollMotion()
  func body(content: Content) -> some View {
    content.scrollPosition($position)
      .onScrollGeometryChange(for: BoardScrollMetrics.self) { geometry in
        if axis == .vertical {
          return BoardScrollMetrics(offset: max(0, geometry.contentOffset.y + geometry.contentInsets.top),
            maximum: max(0, geometry.contentSize.height + geometry.contentInsets.top
              + geometry.contentInsets.bottom - geometry.containerSize.height))
        }
        return BoardScrollMetrics(offset: max(0, geometry.contentOffset.x + geometry.contentInsets.leading),
          maximum: max(0, geometry.contentSize.width + geometry.contentInsets.leading
            + geometry.contentInsets.trailing - geometry.containerSize.width))
      } action: { _, value in
        offset = value.offset
        maximum = value.maximum
      }
      .background {
        BoardEdgeTracker(axis: axis, enabled: enabled, headerID: headerID, scrollOverSidebar: scrollOverSidebar) { velocity in
          guard let next = motion.advance(velocity: velocity, offset: offset,
            maximum: maximum, time: ProcessInfo.processInfo.systemUptime,
            speed: axis == .vertical ? 1200 : 480) else { return }
          var transaction = Transaction()
          transaction.disablesAnimations = true
          withTransaction(transaction) {
            if axis == .vertical { position.scrollTo(y: next) }
            else { position.scrollTo(x: next) }
          }
        }.allowsHitTesting(false)
      }
  }
}
private struct BoardScrollMetrics: Equatable {
  var offset: CGFloat
  var maximum: CGFloat
}
private struct BoardEdgeTracker: NSViewRepresentable {
  var axis: Axis
  var enabled: Bool
  var headerID: UUID?
  var scrollOverSidebar: Bool
  var scroll: (CGFloat) -> Void
  func makeNSView(context: Context) -> BoardEdgeView { BoardEdgeView() }
  func updateNSView(_ view: BoardEdgeView, context: Context) {
    view.axis = axis
    view.enabled = enabled
    view.headerID = headerID
    view.scrollOverSidebar = scrollOverSidebar
    view.scroll = scroll
  }
  static func dismantleNSView(_ view: BoardEdgeView, coordinator: ()) { view.stop() }
}
struct BoardSidebarBoundary: NSViewRepresentable {
  var enabled: Bool
  func makeNSView(context: Context) -> BoardSidebarView { BoardSidebarView() }
  func updateNSView(_ view: BoardSidebarView, context: Context) { view.enabled = enabled }
}
final class BoardSidebarView: NSView {
  static let views = NSHashTable<BoardSidebarView>.weakObjects()
  var enabled = true
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    Self.views.remove(self)
    if window != nil { Self.views.add(self) }
  }
}
struct BoardScrollHeaderBoundary: NSViewRepresentable {
  var id: UUID
  func makeNSView(context: Context) -> BoardScrollHeaderView { BoardScrollHeaderView() }
  func updateNSView(_ view: BoardScrollHeaderView, context: Context) { view.id = id }
}
final class BoardScrollHeaderView: NSView {
  static let views = NSHashTable<BoardScrollHeaderView>.weakObjects()
  var id: UUID?
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    Self.views.remove(self)
    if window != nil { Self.views.add(self) }
  }
}
private final class BoardEdgeView: NSView {
  var scrollOverSidebar = false
  var headerID: UUID?
  var axis: Axis = .horizontal
  var enabled = true
  var scroll: ((CGFloat) -> Void)?
  private var timer: Timer?
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    stop()
    guard window != nil else { return }
    let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.tick() }
    }
    self.timer = timer
    RunLoop.main.add(timer, forMode: .common)
    RunLoop.main.add(timer, forMode: .eventTracking)
  }
  func stop() { timer?.invalidate(); timer = nil }
  private func tick() {
    guard enabled, LandingDragView.isDragging, let window else { scroll?(0); return }
    let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
    var visible = visibleRect
    if let sidebar = BoardSidebarView.views.allObjects.first(where: {
      $0.window === window && $0.enabled && !$0.isHiddenOrHasHiddenAncestor
    }) {
      let sidebarFrame = convert(sidebar.bounds, from: sidebar)
      if axis == .horizontal && scrollOverSidebar && sidebarFrame.contains(point)
        && window.frame.contains(NSEvent.mouseLocation) {
        scroll?(-1)
        return
      }
      if sidebarFrame.maxX > visible.minX && sidebarFrame.minX < visible.maxX {
        let left = min(visible.maxX, sidebarFrame.maxX)
        visible = CGRect(x: left, y: visible.minY, width: visible.maxX - left, height: visible.height)
      }
    }
    if axis == .vertical {
      guard visible.width > 0, visible.height > 0,
        point.x >= visible.minX, point.x <= visible.maxX,
        window.frame.contains(NSEvent.mouseLocation) else { scroll?(0); return }
      let y = isFlipped ? point.y - visible.minY : visible.maxY - point.y
      let edge = min(CGFloat(64), visible.height / 3)
      var distanceFromTop = y
      if let headerID, let header = BoardScrollHeaderView.views.allObjects.first(where: {
        $0.id == headerID && $0.window === window && !$0.isHiddenOrHasHiddenAncestor
      }) {
        let frame = convert(header.bounds, from: header)
        distanceFromTop = isFlipped ? point.y - frame.maxY : frame.minY - point.y
      }
      if distanceFromTop < edge { scroll?(-min(1, (edge - distanceFromTop) / edge)) }
      else if y > visible.height - edge { scroll?(min(1, (y - visible.height + edge) / edge)) }
      else { scroll?(0) }
      return
    }
    guard visible.width > 0, point.y >= visible.minY, point.y <= visible.maxY,
      point.x >= visible.minX - 12, point.x <= visible.maxX + 12 else { scroll?(0); return }
    let edge: CGFloat = 64
    if point.x < visible.minX + edge {
      scroll?(-min(1, (visible.minX + edge - point.x) / edge))
    } else if point.x > visible.maxX - edge {
      scroll?(min(1, (point.x - visible.maxX + edge) / edge))
    } else { scroll?(0) }
  }
}
#endif
