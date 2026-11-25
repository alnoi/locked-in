import SwiftUI

struct ReorderSourceAppearance: ViewModifier {
  var active: Bool
  func body(content: Content) -> some View {
    content.opacity(active ? 0.18 : 1)
  }
}

struct ReorderDragSource: ViewModifier {
  var id: UUID
  var provider: () -> NSItemProvider
  var enabled = true
  @ViewBuilder func body(content: Content) -> some View {
    if enabled {
    #if os(macOS)
      content.background {
        GeometryReader { geometry in
          LandingDragBridge(id: id, layoutFrame: geometry.frame(in: .global), provider: provider)
        }
      }
      .contentShape(Rectangle())
      .onContinuousHover { phase in LandingDragView.track(id: id, phase: phase) }
    #else
      content.contentShape(Rectangle()).onDrag(provider)
    #endif
    } else { content }
  }
}

#if os(macOS)
import AppKit

private struct LandingDragBridge: NSViewRepresentable {
  var id: UUID
  var layoutFrame: CGRect
  var provider: () -> NSItemProvider
  func makeNSView(context: Context) -> LandingDragView { LandingDragView() }
  func updateNSView(_ view: LandingDragView, context: Context) {
    view.id = id
    view.updateGeometry(layoutFrame)
    view.provider = provider
  }
}

/// Uses the same native payload as other drop targets, then lands the preview at the
/// source view's new layout position rather than letting the system image disappear.
final class LandingDragView: NSView, NSDraggingSource {
  private static let candidates = NSHashTable<LandingDragView>.weakObjects()
  private static var active: LandingDragView?
  private(set) static var isDragging = false
  private var landingTargetID: UUID?
  static func redirectLanding(to id: UUID) { active?.landingTargetID = id }
  private static weak var pressed: LandingDragView?
  private static var downPoint = NSPoint.zero
  private var monitor: Any?
  var id: UUID?
  private var draggedID: UUID?
  private var pointerInside = false
  private var layoutFrame = CGRect.zero
  private var screenFrame = CGRect.zero
  static func track(id: UUID, phase: HoverPhase) {
    guard let view = candidates.allObjects.first(where: { $0.id == id }) else { return }
    switch phase {
    case .active(let location):
      view.pointerInside = true
      let mouse = NSEvent.mouseLocation
      view.screenFrame = NSRect(x: mouse.x - location.x,
        y: mouse.y + location.y - view.layoutFrame.height,
        width: view.layoutFrame.width, height: view.layoutFrame.height)
    case .ended: view.pointerInside = false
    }
  }
  func updateGeometry(_ frame: CGRect) {
    if !screenFrame.isEmpty {
      screenFrame.origin.x += frame.minX - layoutFrame.minX
      screenFrame.origin.y -= frame.minY - layoutFrame.minY
      screenFrame.size = frame.size
    }
    layoutFrame = frame
  }
  var provider: (() -> NSItemProvider)?
  private var retainedProvider: NSItemProvider?
  private var previewPanel: NSPanel?
  private let previewScale: CGFloat = 0.72
  private var grabOffset = NSPoint.zero
  private var originalFrame = NSRect.zero
  override func hitTest(_ point: NSPoint) -> NSView? { nil }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    if let monitor { NSEvent.removeMonitor(monitor); self.monitor = nil }
    Self.candidates.remove(self)
    guard window != nil else { return }
    Self.candidates.add(self)
    monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseDragged, .leftMouseUp]) { [weak self] event in
      MainActor.assumeIsolated {
        guard let self else { return event }
        return self.handle(event)
      }
    }
  }
  deinit { if let monitor { NSEvent.removeMonitor(monitor) } }
  private func snapshotImage() -> NSImage? {
    guard let root = window?.contentView else { return nil }
    guard let window else { return nil }
    let rect = root.convert(window.convertFromScreen(screenFrame), from: nil)
    guard let bitmap = root.bitmapImageRepForCachingDisplay(in: rect) else { return nil }
    root.cacheDisplay(in: rect, to: bitmap)
    let image = NSImage(size: screenFrame.size)
    bitmap.size = screenFrame.size
    image.addRepresentation(bitmap)
    return image
  }
  private func handle(_ event: NSEvent) -> NSEvent? {
    guard let window, event.window === window else { return event }
    if event.type == .leftMouseDown {
      let point = event.locationInWindow
      let hit = Self.candidates.allObjects.filter {
        $0.window === window && !$0.isHiddenOrHasHiddenAncestor
          && $0.pointerInside && $0.screenFrame.contains(NSEvent.mouseLocation)
      }.min { $0.layoutFrame.width * $0.layoutFrame.height < $1.layoutFrame.width * $1.layoutFrame.height }
      Self.pressed = hit
      Self.downPoint = point
    } else if event.type == .leftMouseUp {
      Self.pressed = nil
    } else if Self.pressed === self {
      let point = event.locationInWindow
      guard hypot(point.x - Self.downPoint.x, point.y - Self.downPoint.y) > 5,
        let image = snapshotImage(), let provider = provider?()
      else { return event }
      Self.pressed = nil
      landingTargetID = nil
      Self.active = self
      Self.isDragging = true
      draggedID = id
      retainedProvider = provider
      originalFrame = screenFrame
      let down = window.convertPoint(toScreen: Self.downPoint)
      grabOffset = NSPoint(x: down.x - originalFrame.minX, y: down.y - originalFrame.minY)
      guard let payload = provider as? ListDragProvider else { return event }
      let writer: NSPasteboardWriting
      if let typeIdentifier = payload.typeIdentifier {
        let boardItem = NSPasteboardItem()
        boardItem.setString(payload.text, forType: NSPasteboard.PasteboardType(typeIdentifier))
        writer = boardItem
      } else { writer = payload.text as NSString }
      let item = NSDraggingItem(pasteboardWriter: writer)
      let localFrame = convert(window.convertFromScreen(originalFrame), from: nil)
      // The native session carries only the payload. Its destination animation is invisible.
      item.setDraggingFrame(localFrame, contents: NSImage(size: originalFrame.size))
      showPreview(image, at: window.convertPoint(toScreen: point))
      let session = beginDraggingSession(with: [item], event: event, source: self)
      session.animatesToStartingPositionsOnCancelOrFail = false
      return nil
    }
    return event
  }
  func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .move }
  private func previewFrame(at point: NSPoint) -> NSRect {
    NSRect(x: point.x - grabOffset.x * previewScale,
           y: point.y - grabOffset.y * previewScale,
           width: originalFrame.width * previewScale,
           height: originalFrame.height * previewScale)
  }
  private func showPreview(_ image: NSImage, at point: NSPoint) {
    let frame = previewFrame(at: point)
    let panel = NSPanel(contentRect: frame, styleMask: .borderless, backing: .buffered, defer: false)
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.ignoresMouseEvents = true
    panel.level = .floating
    panel.hasShadow = true
    panel.alphaValue = 0.65
    let imageView = NSImageView(frame: NSRect(origin: .zero, size: frame.size))
    imageView.autoresizingMask = [.width, .height]
    let dimmedImage = NSImage(size: image.size, flipped: false) { rect in
      image.draw(in: rect)
      NSColor.black.withAlphaComponent(0.24).setFill()
      rect.fill(using: .sourceAtop)
      return true
    }
    imageView.image = dimmedImage
    imageView.imageScaling = .scaleAxesIndependently
    panel.contentView = imageView
    previewPanel = panel
    panel.orderFrontRegardless()
  }
  func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) {
    previewPanel?.setFrame(previewFrame(at: screenPoint), display: true)
  }
  func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
    Self.isDragging = false
    guard let panel = previewPanel else { retainedProvider = nil; Self.active = nil; return }
    panel.setFrame(previewFrame(at: screenPoint), display: true)
    if operation.isEmpty { (retainedProvider as? ListDragProvider)?.finish() }
    DispatchQueue.main.async { [self, panel] in
      let destination = Self.candidates.allObjects.first {
        $0.id == (landingTargetID ?? draggedID) && $0.window != nil && !$0.isHiddenOrHasHiddenAncestor
      }
      destination?.window?.contentView?.layoutSubtreeIfNeeded()
      let layoutFrame = destination.map { $0.screenFrame }
      let validFrame = layoutFrame.flatMap { frame in
        frame.width > 1 && frame.height > 1 ? frame : nil
      } ?? originalFrame
      // Anchor the full column at its top edge, even if layout is still interpolating.
      let target = validFrame
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.08
        context.timingFunction = CAMediaTimingFunction(name: .easeOut)
        panel.animator().setFrame(target, display: true)
        panel.animator().alphaValue = 1
      } completionHandler: { [self, panel] in
        panel.orderOut(nil)
        (retainedProvider as? ListDragProvider)?.finish()
        retainedProvider = nil
        previewPanel = nil
        Self.active = nil
      }
    }
  }
}
#endif
