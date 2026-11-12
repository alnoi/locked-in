import SwiftUI

struct CalendarPeriodSwipe: ViewModifier {
  var enabled: Bool
  var shift: (Int) -> Void
  #if os(macOS)
  @State private var hovered = false
  #endif
  func body(content: Content) -> some View {
    #if os(macOS)
      content.background {
        CalendarTrackpadBridge(enabled: enabled && hovered, shift: shift)
      }.onContinuousHover { phase in
        switch phase { case .active: hovered = true; case .ended: hovered = false }
      }
    #else
      content.simultaneousGesture(DragGesture(minimumDistance: 35).onEnded { value in
        guard enabled, abs(value.translation.width) > 70,
          abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
        shift(value.translation.width < 0 ? 1 : -1)
      })
    #endif
  }
}

#if os(macOS)
import AppKit

private struct CalendarTrackpadBridge: NSViewRepresentable {
  var enabled: Bool
  var shift: (Int) -> Void
  func makeNSView(context: Context) -> CalendarTrackpadView { CalendarTrackpadView() }
  func updateNSView(_ view: CalendarTrackpadView, context: Context) {
    view.enabled = enabled
    view.shift = shift
  }
}
private final class CalendarTrackpadView: NSView {
  var enabled = false
  var shift: ((Int) -> Void)?
  private var monitor: Any?
  private var distance: CGFloat = 0
  private var changedPeriod = false
  private var lastEvent: TimeInterval = 0
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    guard window != nil else { return }
    monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
      MainActor.assumeIsolated {
        guard let self else { return event }
        return self.handle(event)
      }
    }
  }
  deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
  private func handle(_ event: NSEvent) -> NSEvent? {
    guard enabled, event.window === window else { distance = 0; changedPeriod = false; return event }
    if !event.momentumPhase.isEmpty { return changedPeriod ? nil : event }
    if event.phase.contains(.began) || event.timestamp - lastEvent > 0.3 {
      distance = 0; changedPeriod = false
    }
    lastEvent = event.timestamp
    guard abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) * 1.5 else { return event }
    distance += event.scrollingDeltaX
    if !changedPeriod && abs(distance) >= 65 {
      changedPeriod = true
      shift?(distance < 0 ? 1 : -1)
    }
    return nil
  }
}
#endif
