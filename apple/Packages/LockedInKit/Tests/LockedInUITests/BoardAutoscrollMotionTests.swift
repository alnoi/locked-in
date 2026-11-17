import XCTest
@testable import LockedInUI

final class BoardAutoscrollMotionTests: XCTestCase {
  func testDelayedGeometryCannotAccumulateLargeJump() {
    var motion = BoardAutoscrollMotion()
    for frame in 0..<120 {
      let next = motion.advance(velocity: 1, offset: 100, maximum: 2000,
        time: Double(frame) / 60)
      if let next { XCTAssertTrue((100...110).contains(next)) }
    }
  }
  func testReentryAndReversalStartAtActualPosition() {
    var motion = BoardAutoscrollMotion()
    _ = motion.advance(velocity: 1, offset: 400, maximum: 2000, time: 0)
    _ = motion.advance(velocity: 1, offset: 400, maximum: 2000, time: 0.2)
    XCTAssertNil(motion.advance(velocity: 0, offset: 400, maximum: 2000, time: 0.3))
    XCTAssertNil(motion.advance(velocity: -1, offset: 800, maximum: 2000, time: 0.4))
    let next = motion.advance(velocity: -1, offset: 800, maximum: 2000, time: 0.42)!
    XCTAssertTrue((790..<800).contains(next))
  }
  func testLongFrameStartsGentlyAndStaysWithinBounds() {
    var motion = BoardAutoscrollMotion()
    XCTAssertNil(motion.advance(velocity: 1, offset: 995, maximum: 1000, time: 0))
    let next = motion.advance(velocity: 1, offset: 995, maximum: 1000, time: 5)!
    XCTAssertEqual(next, 1000)
  }
}
