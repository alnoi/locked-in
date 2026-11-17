#if os(macOS)
  import AppKit
  import QuartzCore
  import LockedInDomain
  import SwiftUI

  struct MacTaskInspector: NSViewRepresentable {
    @Bindable var model: AppModel
    var task: TaskRecord
    var centered = false
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
      guard !context.coordinator.isShown, view.window != nil else { return }
      let content = TaskEditor(
        model: model, presentation: TaskPresentation(taskID: task.id, input: TaskInput(task)),
        close: { binding.wrappedValue = false }
      )
      .environment(\.locale, locale).environment(\.colorScheme, colorScheme).tint(Color.accent)
      context.coordinator.show(content, anchoredTo: view, centered: centered)
    }
    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) { coordinator.close() }
    @MainActor final class Coordinator: NSObject {
      private var panel: InspectorPanel?
      var isShown: Bool { panel?.isVisible == true }
      var closed: (() -> Void)?
      private var clickMonitor: Any?
      private var outsideMonitor: Any?
      func show<Content: View>(_ content: Content, anchoredTo anchor: NSView, centered: Bool) {
        guard let parent = anchor.window, let screen = parent.screen else { return }
        let task = parent.convertToScreen(anchor.convert(anchor.bounds, to: nil))
        let screenBounds = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let visible = parent.frame.intersection(screenBounds)
        let width: CGFloat = centered ? 380 : 392
        let height: CGFloat = 620
        let onRight = screenBounds.maxX - task.maxX >= width
          || task.minX - screenBounds.minX < width
        let area = visible.isEmpty ? screenBounds : visible
        let x = centered ? area.midX - width / 2 : onRight ? task.maxX : task.minX - width
        var y = centered ? area.midY - height / 2 : task.midY - height / 2
        if y < area.minY || y + height > area.maxY { y = area.midY - height / 2 }
        y = max(screenBounds.minY, min(y, screenBounds.maxY - height))
        let arrowY = max(24, min(height - 24, height - (task.midY - y)))
        let body = HStack(spacing: 0) {
          if !centered && onRight { InspectorArrow(pointsRight: false).fill(.regularMaterial)
            .frame(width: 12, height: 22).offset(y: arrowY - height / 2) }
          content
          if !centered && !onRight { InspectorArrow(pointsRight: true).fill(.regularMaterial)
            .frame(width: 12, height: 22).offset(y: arrowY - height / 2) }
        }.frame(width: width, height: height)
        let window = InspectorPanel(contentRect: NSRect(x: x, y: y, width: width, height: height),
          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        window.appearance = parent.effectiveAppearance
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: body)
        panel = window
        let finalFrame = window.frame
        window.setFrame(finalFrame.insetBy(dx: finalFrame.width * 0.06, dy: finalFrame.height * 0.06), display: false)
        window.alphaValue = 0
        parent.addChildWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
          context.duration = 0.12
          context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
          window.animator().alphaValue = 1
          window.animator().setFrame(finalFrame, display: true)
        }
        clickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])
        { [weak self, weak anchor, weak parent] event in
          guard let self else { return event }
          if event.window === parent {
            let repeatedClick = anchor.map {
              $0.bounds.contains($0.convert(event.locationInWindow, from: nil))
            } ?? false
            self.dismiss()
            if repeatedClick { return nil }
          }
          return event
        }
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown])
          { [weak self] _ in Task { @MainActor in self?.dismiss() } }
      }
      private func dismiss() { close(); closed?() }
      func close() {
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor); self.clickMonitor = nil }
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor); self.outsideMonitor = nil }
        if let panel {
          self.panel = nil
          panel.ignoresMouseEvents = true
          let frame = panel.frame
          let target = frame.insetBy(dx: frame.width * 0.06, dy: frame.height * 0.06)
          NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(target, display: true)
          } completionHandler: {
            Task { @MainActor in
              panel.parent?.removeChildWindow(panel)
              panel.close()
            }
          }
        }
      }
    }
  }
  private final class InspectorPanel: NSPanel {
    override var canBecomeKey: Bool { true }
  }
  private struct InspectorArrow: Shape {
    let pointsRight: Bool
    func path(in rect: CGRect) -> Path {
      Path { path in
        path.move(to: CGPoint(x: pointsRight ? 0 : rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: pointsRight ? rect.maxX : 0, y: rect.midY))
        path.addLine(to: CGPoint(x: pointsRight ? 0 : rect.maxX, y: rect.maxY))
        path.closeSubpath()
      }
    }
  }
#endif
