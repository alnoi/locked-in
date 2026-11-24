import SwiftUI

extension View {
  func submitOnEnter(enabled: Bool = true, perform action: @escaping () -> Void) -> some View {
    background {
      AppShortcutHandler(priority: 200, enabled: enabled, submitOnReturn: true) { shortcut in
        guard shortcut == .submit else { return false }
        action()
        return true
      }.allowsHitTesting(false)
    }
  }
}
