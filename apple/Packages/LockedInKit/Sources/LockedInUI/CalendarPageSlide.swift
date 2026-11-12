import SwiftUI

// Outgoing and incoming pages share the direction of the current navigation,
// instead of retaining the direction from the transition that created a page.
final class CalendarPageDirection {
  var sign: CGFloat = 1
}
struct CalendarPageSlide: GeometryEffect {
  var progress: CGFloat
  var direction: CalendarPageDirection
  var animatableData: CGFloat {
    get { progress }
    set { progress = newValue }
  }
  func effectValue(size: CGSize) -> ProjectionTransform {
    ProjectionTransform(CGAffineTransform(translationX: progress * direction.sign * size.width, y: 0))
  }
}
