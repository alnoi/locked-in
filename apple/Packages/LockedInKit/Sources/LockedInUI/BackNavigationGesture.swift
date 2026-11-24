import SwiftUI

struct BackNavigationGesture: ViewModifier {
  var enabled: Bool
  var back: () -> Void
  func body(content: Content) -> some View {
    #if os(macOS)
    content.background {
      BackTrackpadBridge(enabled: enabled, back: back).allowsHitTesting(false)
    }
    #else
    content
    #endif
  }
}

#if os(macOS)
import AppKit

private struct BackTrackpadBridge: NSViewRepresentable {
  var enabled: Bool
  var back: () -> Void
  func makeNSView(context: Context) -> BackTrackpadView { BackTrackpadView() }
  func updateNSView(_ view: BackTrackpadView, context: Context) {
    view.enabled = enabled
    view.back = back
  }
}

private final class BackTrackpadView: NSView {
  var enabled = false
  var back: (() -> Void)?
  private var monitor: Any?
  private var distance: CGFloat = 0
  private var triggered = false
  private var lastEvent: TimeInterval = 0
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    guard window != nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .swipe]) { [weak self] event in
      guard let self else { return event }
      return self.handle(event)
    }
  }
  deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
  private func handle(_ event: NSEvent) -> NSEvent? {
    guard enabled, event.window === window, window?.isKeyWindow == true,
      window?.attachedSheet == nil, !LandingDragView.isDragging,
      bounds.contains(convert(event.locationInWindow, from: nil)) else {
      distance = 0
      triggered = false
      return event
    }
    if event.type == .swipe {
      guard event.deltaX > 0, !triggered else { return event }
      triggered = true
      back?()
      return nil
    }
    guard event.hasPreciseScrollingDeltas else { return event }
    if !event.momentumPhase.isEmpty { return triggered ? nil : event }
    if event.phase.contains(.began) || event.timestamp - lastEvent > 0.3 {
      distance = 0
      triggered = false
    }
    lastEvent = event.timestamp
    guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.5 else {
      distance = 0
      return event
    }
    distance = max(0, distance + event.scrollingDeltaX)
    guard distance > 0 else { return event }
    if !triggered && distance >= 70 {
      triggered = true
      back?()
    }
    return nil
  }
}
#endif
