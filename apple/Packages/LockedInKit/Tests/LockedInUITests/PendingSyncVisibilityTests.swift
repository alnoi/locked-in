import XCTest
@testable import LockedInUI

final class PendingSyncVisibilityTests: XCTestCase {
  func testFastAcknowledgementNeverShowsFlagAndSlowSyncWaitsOneSecond() {
    let id = UUID(), second = UUID()
    let start = Date(timeIntervalSince1970: 1000)
    var state = PendingSyncVisibility()
    state.update([id], at: start)
    XCTAssertTrue(state.visible(at: start.addingTimeInterval(0.99)).isEmpty)
    state.update([], at: start.addingTimeInterval(0.2))
    XCTAssertTrue(state.visible(at: start.addingTimeInterval(2)).isEmpty)
    state.update([id], at: start.addingTimeInterval(3))
    state.update([id, second], at: start.addingTimeInterval(3.5))
    XCTAssertEqual(state.visible(at: start.addingTimeInterval(4)), [id])
    XCTAssertEqual(state.nextAppearance(at: start.addingTimeInterval(4)), 0.5)
    state.update([second], at: start.addingTimeInterval(4.2))
    XCTAssertTrue(state.visible(at: start.addingTimeInterval(4.2)).isEmpty)
    XCTAssertEqual(state.visible(at: start.addingTimeInterval(4.5)), [second])
  }
}
