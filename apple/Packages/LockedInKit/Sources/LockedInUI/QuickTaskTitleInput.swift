import SwiftUI

struct QuickTaskTitleInput: View {
  @Binding var title: String
  @Binding var focused: Bool
  #if os(iOS)
  @FocusState private var fieldFocused: Bool
  #endif
  var submit: () -> Void
  var body: some View {
    #if os(macOS)
    NativeQuickTaskTitle(title: $title, focused: $focused, submit: submit)
    #else
    TextField(focused ? "Название задачи" : "", text: $title, axis: .vertical)
      .lineLimit(1...).textFieldStyle(.plain).font(.body.weight(.medium))
      .focused($fieldFocused).onSubmit(submit)
      .onAppear { fieldFocused = focused }
      .onChange(of: focused) { _, value in if fieldFocused != value { fieldFocused = value } }
      .onChange(of: fieldFocused) { _, value in if focused != value { focused = value } }
    #endif
  }
}

#if os(macOS)
import AppKit

private struct NativeQuickTaskTitle: NSViewRepresentable {
  @Binding var title: String
  @Binding var focused: Bool
  var submit: () -> Void
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  func makeNSView(context: Context) -> TitleView {
    let view = TitleView()
    view.drawsBackground = false
    view.backgroundColor = .clear
    view.isRichText = false
    view.importsGraphics = false
    view.isVerticallyResizable = true
    view.isHorizontallyResizable = false
    view.allowsUndo = true
    view.textContainerInset = .zero
    view.textContainer?.lineFragmentPadding = 0
    view.textContainer?.widthTracksTextView = true
    view.font = .systemFont(ofSize: NSFont.systemFontSize, weight: .medium)
    view.textColor = .labelColor
    view.insertionPointColor = NSColor(Color.accent)
    view.delegate = context.coordinator
    view.setAccessibilityLabel("Новая задача в списке")
    return view
  }
  func updateNSView(_ view: TitleView, context: Context) {
    context.coordinator.parent = self
    if view.isEditable != context.environment.isEnabled { view.isEditable = context.environment.isEnabled }
    let appearance: NSAppearance.Name = context.environment.colorScheme == .dark ? .darkAqua : .aqua
    if view.appearance?.name != appearance { view.appearance = NSAppearance(named: appearance) }
    if view.string != title && !view.hasMarkedText() {
      view.string = title
      view.setSelectedRange(NSRange(location: title.utf16.count, length: 0))
      view.invalidateIntrinsicContentSize()
    }
    view.focusChanged = { value in
      if context.coordinator.parent.focused != value { context.coordinator.parent.focused = value }
    }
    view.wantsFocus = focused
    view.updateFocus()
    view.needsDisplay = true
  }
  func sizeThatFits(_ proposal: ProposedViewSize, nsView: TitleView, context: Context) -> CGSize? {
    guard let width = proposal.width, width > 0, let container = nsView.textContainer,
      let layout = nsView.layoutManager else { return nil }
    container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
    layout.ensureLayout(for: container)
    let lineHeight = layout.defaultLineHeight(for: nsView.font ?? .systemFont(ofSize: NSFont.systemFontSize))
    return CGSize(width: width, height: ceil(max(lineHeight, layout.usedRect(for: container).height)))
  }
  final class Coordinator: NSObject, NSTextViewDelegate {
    var parent: NativeQuickTaskTitle
    init(_ parent: NativeQuickTaskTitle) { self.parent = parent }
    func textDidChange(_ notification: Notification) {
      guard let view = notification.object as? TitleView else { return }
      parent.title = view.string
      view.invalidateIntrinsicContentSize()
      view.needsDisplay = true
    }
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
      if selector == #selector(NSResponder.insertNewline(_:)), !textView.hasMarkedText() {
        parent.submit()
        return true
      }
      return false
    }
  }
  final class TitleView: NSTextView {
    var wantsFocus = false
    var focusChanged: ((Bool) -> Void)?
    override var intrinsicContentSize: NSSize {
      NSSize(width: NSView.noIntrinsicMetric,
        height: layoutManager?.defaultLineHeight(for: font ?? .systemFont(ofSize: NSFont.systemFontSize)) ?? 17)
    }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); updateFocus() }
    func updateFocus() {
      guard let window else { return }
      if wantsFocus, window.firstResponder !== self { window.makeFirstResponder(self) }
      else if !wantsFocus, window.firstResponder === self { window.makeFirstResponder(nil) }
    }
    override func becomeFirstResponder() -> Bool {
      let accepted = super.becomeFirstResponder()
      if accepted { focusChanged?(true); needsDisplay = true }
      return accepted
    }
    override func resignFirstResponder() -> Bool {
      let accepted = super.resignFirstResponder()
      if accepted { focusChanged?(false); needsDisplay = true }
      return accepted
    }
    override func draw(_ dirtyRect: NSRect) {
      super.draw(dirtyRect)
      if string.isEmpty, window?.firstResponder === self {
        ("Название задачи" as NSString).draw(at: .zero, withAttributes: [
          .font: font ?? NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .medium),
          .foregroundColor: NSColor.placeholderTextColor
        ])
      }
    }
  }
}
#endif
