#if os(macOS)
import AppKit
import SwiftUI

struct SidebarHoverTracker: NSViewRepresentable {
  var enabled: Bool
  var shown: Bool
  var changed: (Bool) -> Void
  func makeNSView(context: Context) -> SidebarHoverView { SidebarHoverView() }
  func updateNSView(_ view: SidebarHoverView, context: Context) {
    view.enabled = enabled
    view.shown = shown
    view.changed = changed
  }
  static func dismantleNSView(_ view: SidebarHoverView, coordinator: ()) { view.stop() }
}
final class SidebarHoverView: NSView {
  var enabled = false
  var shown = false
  var changed: ((Bool) -> Void)?
  private var timer: Timer?
  private var pending: Bool?
  private var since: TimeInterval = 0
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
  func stop() { timer?.invalidate(); timer = nil; pending = nil }
  private func tick() {
    guard enabled, let window else { pending = nil; return }
    guard !LandingDragView.isDragging, NSEvent.pressedMouseButtons == 0 else {
      pending = nil
      return
    }
    let point = convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
    let area = visibleRect
    let inside = area.contains(point) && NSApp.isActive
    let desired = inside && point.x < area.minX + (shown ? 260 : 28)
    guard desired != shown else { pending = nil; return }
    let now = ProcessInfo.processInfo.systemUptime
    if pending != desired { pending = desired; since = now; return }
    guard now - since >= (desired ? 0.04 : 0.10) else { return }
    pending = nil
    shown = desired
    changed?(desired)
  }
}
#endif
