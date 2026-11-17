import SwiftUI

enum AppShortcut: Equatable {
  case search, newInboxTask, sidebar, submit, close, complete, delete, project, links, unplan
  case previousPeriod, nextPeriod, today, day, week, month, previousSection, finishSectionSwitch

  static func key(code: UInt16, fallback: String) -> String {
    let keys: [UInt16: String] = [
      36: "return", 76: "return", 48: "tab", 53: "escape", 51: "delete", 123: "left", 124: "right",
      3: "f", 17: "t", 1: "s", 37: "l", 35: "p", 18: "1", 19: "2", 20: "3",
    ]
    return keys[code] ?? fallback
  }

  static func match(key: String, modifiers: EventModifiers, editingText: Bool) -> Self? {
    let modifiers = modifiers.intersection([.command, .shift, .control, .option])
    let key = key.lowercased()
    if modifiers == .control && key == "tab" { return .previousSection }
    if modifiers == .command {
      switch key {
      case "f": return .search
      case "t": return .newInboxTask
      case "s": return .sidebar
      case "l": return .links
      case "return": return .submit
      case "delete": return .delete
      default: return nil
      }
    }
    if modifiers == [.command, .shift] {
      switch key {
      case "return": return .complete
      case "p": return .project
      case "delete": return .unplan
      default: return nil
      }
    }
    guard modifiers.isEmpty else { return nil }
    if key == "escape" { return .close }
    if key == "return" { return editingText ? nil : .submit }
    guard !editingText else { return nil }
    switch key {
    case "left": return .previousPeriod
    case "right": return .nextPeriod
    case "t": return .today
    case "1": return .day
    case "2": return .week
    case "3": return .month
    default: return nil
    }
  }
}

extension Notification.Name {
  static let appShortcut = Notification.Name("TrackIt.appShortcut")
}

#if os(macOS)
import AppKit

struct AppShortcutHandler: NSViewRepresentable {
  var priority = 0
  var enabled = true
  var focusOnAppear = false
  var submitDatePickerOnReturn = false
  var handle: (AppShortcut) -> Bool

  func makeNSView(context: Context) -> ShortcutView { ShortcutView() }
  func updateNSView(_ view: ShortcutView, context: Context) {
    view.priority = priority
    view.enabled = enabled
    view.handle = handle
    view.wantsInitialFocus = focusOnAppear
    view.submitDatePickerOnReturn = submitDatePickerOnReturn
    view.focusInitially()
  }

  @MainActor final class ShortcutView: NSView {
    private static let views = NSHashTable<ShortcutView>.weakObjects()
    private static var monitor: Any?
    private static var controlHeld = false
    var priority = 0
    var enabled = true
    var handle: ((AppShortcut) -> Bool)?
    private var focusedInitially = false
    var wantsInitialFocus = false
    var submitDatePickerOnReturn = false
    override var acceptsFirstResponder: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      Self.views.remove(self)
      guard window != nil else { return }
      Self.views.add(self)
      focusInitially()
      if Self.monitor == nil {
        Self.monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
          let handled = MainActor.assumeIsolated { Self.dispatch(event) }
          return handled ? nil : event
        }
      }
    }
    func focusInitially() {
      guard wantsInitialFocus, !focusedInitially, window != nil else { return }
      focusedInitially = true
      DispatchQueue.main.async { [weak self] in
        guard let self, let window = self.window else { return }
        window.makeFirstResponder(self)
      }
    }
    private static func editingDatePicker(in window: NSWindow) -> NSDatePicker? {
      if let picker = window.firstResponder as? NSDatePicker { return picker }
      guard let editor = window.firstResponder as? NSTextView else { return nil }
      func find(in view: NSView) -> NSDatePicker? {
        if let picker = view as? NSDatePicker, picker.currentEditor() === editor { return picker }
        for child in view.subviews {
          if let picker = find(in: child) { return picker }
        }
        return nil
      }
      return window.contentView.flatMap { find(in: $0) }
    }
    private static func dispatch(_ event: NSEvent) -> Bool {
      let holdingControl = event.modifierFlags.contains(.control)
      let releasedControl = controlHeld && !holdingControl
      controlHeld = holdingControl
      if releasedControl {
        NotificationCenter.default.post(name: .appShortcut, object: AppShortcut.finishSectionSwitch)
      }
      guard event.type == .keyDown else { return false }
      guard let window = event.window ?? NSApp.keyWindow else { return false }
      let editingText = window.firstResponder is NSTextView || window.firstResponder is NSTextField
        || window.firstResponder is NSDatePicker || window.firstResponder is NSComboBox
      var modifiers: EventModifiers = []
      if event.modifierFlags.contains(.command) { modifiers.insert(.command) }
      if event.modifierFlags.contains(.shift) { modifiers.insert(.shift) }
      if event.modifierFlags.contains(.control) { modifiers.insert(.control) }
      if event.modifierFlags.contains(.option) { modifiers.insert(.option) }
      let key = AppShortcut.key(code: event.keyCode, fallback: event.charactersIgnoringModifiers ?? "")
      let candidates = views.allObjects.filter {
        $0.enabled && $0.window === window && !$0.isHiddenOrHasHiddenAncestor
      }.sorted { $0.priority > $1.priority }
      if key == "return", modifiers.isEmpty,
        let handler = candidates.first(where: { $0.submitDatePickerOnReturn }),
        let picker = editingDatePicker(in: window) {
        // NSDatePicker consumes Return without emitting SwiftUI's onSubmit.
        // End native editing before the task reads the bound date value.
        picker.validateEditing()
        guard window.makeFirstResponder(nil) else { return true }
        DispatchQueue.main.async { _ = handler.handle?(.submit) }
        return true
      }
      guard let shortcut = AppShortcut.match(key: key, modifiers: modifiers,
        editingText: editingText) else { return false }
      for view in candidates where view.handle?(shortcut) == true { return true }
      return false
    }
  }
}
#else
struct AppShortcutHandler: View {
  var priority = 0
  var enabled = true
  var focusOnAppear = false
  var submitDatePickerOnReturn = false
  var handle: (AppShortcut) -> Bool
  var body: some View { Color.clear.allowsHitTesting(false) }
}
#endif
