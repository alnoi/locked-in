import SwiftUI
import XCTest
@testable import LockedInUI

final class CalendarPageSlideTests: XCTestCase {
  func testExistingOutgoingPageUsesCurrentNavigationDirection() {
    let direction = CalendarPageDirection()
    let outgoing = CalendarPageSlide(progress: -1, direction: direction)
    let incoming = CalendarPageSlide(progress: 1, direction: direction)
    let size = CGSize(width: 300, height: 600)
    // Keep the outgoing effect from the previous render while alternating navigation.
    for sign: CGFloat in [1, -1, -1, 1, 1, -1] {
      direction.sign = sign
      XCTAssertEqual(outgoing.effectValue(size: size).m31, -300 * sign)
      XCTAssertEqual(incoming.effectValue(size: size).m31, 300 * sign)
    }
    XCTAssertEqual(CalendarPageSlide(progress: 0, direction: direction).effectValue(size: size).m31, 0)
  }
}
