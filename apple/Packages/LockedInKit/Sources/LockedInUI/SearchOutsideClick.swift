import SwiftUI

#if os(macOS)
import AppKit

struct SearchOutsideClick: NSViewRepresentable {
  func makeCoordinator() -> Coordinator { Coordinator() }
  func makeNSView(context: Context) -> NSView { NSView() }
  func updateNSView(_ view: NSView, context: Context) { context.coordinator.watch(view) }
  static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.stop() }

  @MainActor final class Coordinator {
    private var monitor: Any?
    func watch(_ anchor: NSView) {
      guard monitor == nil else { return }
      monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
        [weak self, weak anchor] event in
        MainActor.assumeIsolated {
          if let anchor { self?.blurIfOutside(event, anchor: anchor) }
        }
        return event
      }
    }
    private func blurIfOutside(_ event: NSEvent, anchor: NSView) {
      guard let window = anchor.window, let responder = window.firstResponder else { return }
      let search = (responder as? NSSearchField)
        ?? ((responder as? NSTextView)?.delegate as? NSSearchField)
        ?? findSearch(in: window.contentView?.superview, responder: responder)
      guard let search else { return }
      if event.window === window,
        search.bounds.contains(search.convert(event.locationInWindow, from: nil)) { return }
      window.makeFirstResponder(nil)
    }
    private func findSearch(in view: NSView?, responder: NSResponder) -> NSSearchField? {
      guard let view else { return nil }
      if let search = view as? NSSearchField, search.currentEditor() === responder { return search }
      for child in view.subviews {
        if let search = findSearch(in: child, responder: responder) { return search }
      }
      return nil
    }
    func stop() {
      if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    }
  }
}
#else
struct SearchOutsideClick: View {
  var body: some View { Color.clear.allowsHitTesting(false) }
}
#endif
