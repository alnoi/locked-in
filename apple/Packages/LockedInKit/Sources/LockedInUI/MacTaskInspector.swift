#if os(macOS)
  import AppKit
  import LockedInDomain
  import SwiftUI

  struct MacTaskInspector: NSViewRepresentable {
    @Bindable var model: AppModel
    var task: TaskRecord
    @Binding var isPresented: Bool
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
      let binding = $isPresented
      context.coordinator.closed = { binding.wrappedValue = false }
      if !isPresented {
        context.coordinator.close()
        return
      }
      guard !context.coordinator.popover.isShown, view.window != nil else { return }
      let content = TaskEditor(
        model: model, presentation: TaskPresentation(taskID: task.id, input: TaskInput(task)),
        close: { binding.wrappedValue = false }
      )
      .environment(\.locale, locale).environment(\.colorScheme, colorScheme).tint(Color.accent)
      context.coordinator.show(content, anchoredTo: view)
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.close() }
    @MainActor final class Coordinator: NSObject, NSPopoverDelegate {
      let popover = NSPopover()
      var closed: (() -> Void)?
      private var clickMonitor: Any?
      override init() {
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
      }
      func show<Content: View>(_ content: Content, anchoredTo anchor: NSView) {
        popover.contentViewController = NSHostingController(rootView: content)
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])
        { [weak self, weak anchor] event in
          guard let self, let anchor, self.popover.isShown, event.window === anchor.window,
            anchor.bounds.contains(anchor.convert(event.locationInWindow, from: nil))
          else { return event }
          self.close()
          self.closed?()
          return nil
        }
      }
      func close() {
        if let clickMonitor {
          NSEvent.removeMonitor(clickMonitor)
          self.clickMonitor = nil
        }
        popover.close()
      }
      func popoverDidClose(_ notification: Notification) {
        if let clickMonitor {
          NSEvent.removeMonitor(clickMonitor)
          self.clickMonitor = nil
        }
        closed?()
      }
    }
  }
#endif
