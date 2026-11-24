#if os(iOS)
import SwiftUI

// Edge lanes reserve history navigation; gestures inside a calendar or board stay local.
struct PhoneHistoryGestures: ViewModifier {
  var enabled: Bool
  var canGoBack: Bool
  var canGoForward: Bool
  var back: () -> Void
  var forward: () -> Void
  func body(content: Content) -> some View {
    content
      .overlay(alignment: .leading) {
        if enabled && canGoBack { lane(rightward: true, action: back) }
      }
      .overlay(alignment: .trailing) {
        if enabled && canGoForward { lane(rightward: false, action: forward) }
      }
  }
  private func lane(rightward: Bool, action: @escaping () -> Void) -> some View {
    Color.clear.frame(width: 24).contentShape(Rectangle())
      .gesture(DragGesture(minimumDistance: 12).onEnded { value in
        let direction: CGFloat = rightward ? 1 : -1
        let distance = value.translation.width * direction
        let projected = value.predictedEndTranslation.width * direction
        guard distance > 24, max(distance, projected) > 80,
          distance > abs(value.translation.height) * 1.5 else { return }
        action()
      })
      .accessibilityHidden(true)
  }
}
#endif
