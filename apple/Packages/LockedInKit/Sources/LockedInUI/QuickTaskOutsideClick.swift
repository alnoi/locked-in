import SwiftUI

#if os(macOS)
  import AppKit

  struct QuickTaskOutsideClick: NSViewRepresentable {
    var enabled: Bool
    var includeSheetParent = false
    var outside: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
      context.coordinator.outside = outside
      context.coordinator.watch(view, enabled: enabled, includeSheetParent: includeSheetParent)
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.stop() }
    @MainActor final class Coordinator {
      var outside: (() -> Void)?
      private var monitor: Any?
      private var resignation: NSObjectProtocol?
      func watch(_ anchor: NSView, enabled: Bool, includeSheetParent: Bool) {
        guard enabled else {
          stop()
          return
        }
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
          [weak self, weak anchor] event in
          guard let self, let anchor else { return event }
          if includeSheetParent, let parent = anchor.window?.sheetParent, event.window === parent {
            self.outside?()
            return nil
          }
          guard event.window === anchor.window else { return event }
          if !anchor.bounds.contains(anchor.convert(event.locationInWindow, from: nil)) {
            self.outside?()
          }
          return event
        }
        resignation = NotificationCenter.default.addObserver(
          forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.outside?() }
        }
      }
      func stop() {
        if let monitor {
          NSEvent.removeMonitor(monitor)
          self.monitor = nil
        }
        if let resignation {
          NotificationCenter.default.removeObserver(resignation)
          self.resignation = nil
        }
      }
    }
  }
#else
  struct QuickTaskOutsideClick: View {
    var enabled: Bool
    var includeSheetParent = false
    var outside: () -> Void
    @State private var frame: CGRect = .zero
    var body: some View {
      GeometryReader { geometry in
        Color.clear.onAppear { frame = geometry.frame(in: .global) }
          .onChange(of: geometry.frame(in: .global)) { _, value in frame = value }
      }.onReceive(NotificationCenter.default.publisher(for: .quickTaskOutsideTap)) { notification in
        guard enabled, let point = notification.object as? CGPoint, !frame.contains(point) else {
          return
        }
        outside()
      }
    }
  }
  extension Notification.Name {
    static let quickTaskOutsideTap = Notification.Name("LockedIn.quickTaskOutsideTap")
  }
#endif
