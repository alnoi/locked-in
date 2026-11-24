import SwiftUI

extension View {
  func dismissOnOutsideClick(enabled: Bool = true, perform: (() -> Void)? = nil) -> some View {
    modifier(OutsideDismissModifier(enabled: enabled, action: perform))
  }
}

private struct OutsideDismissModifier: ViewModifier {
  var enabled: Bool
  var action: (() -> Void)?
  @Environment(\.dismiss) private var dismiss
  func body(content: Content) -> some View {
    content.background {
      QuickTaskOutsideClick(enabled: enabled, includeSheetParent: true, checkViewBounds: false) {
        if let action { action() } else { dismiss() }
      }.allowsHitTesting(false)
    }
  }
}
