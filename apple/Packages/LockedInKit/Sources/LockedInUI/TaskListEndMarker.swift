import SwiftUI

struct TaskListEndMarker: ViewModifier {
  let space: UUID
  let changed: (CGFloat) -> Void
  func body(content: Content) -> some View {
    content.background {
      GeometryReader { geometry in
        Color.clear.onAppear { changed(geometry.frame(in: .named(space)).minY) }
          .onChange(of: geometry.frame(in: .named(space)).minY) { _, value in changed(value) }
      }
    }
  }
}
