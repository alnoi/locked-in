import XCTest
@testable import LockedInUI

final class NavigationHistoryTests: XCTestCase {
  func testSeparateControlPressesToggleTheLastTwoSections() {
    var history = NavigationHistory(initial: "board")
    history.visit("work")
    history.visit("calendar")
    history.visit("tags")
    XCTAssertEqual(history.previous(), "calendar")
    history.visit("calendar")
    history.finishSwitching()
    XCTAssertEqual(history.previous(), "tags")
    history.finishSwitching()
    XCTAssertEqual(history.previous(), "calendar")
  }

  func testHeldControlUsesAFrozenOrderUntilRelease() {
    var history = NavigationHistory(initial: "board")
    history.visit("work")
    history.visit("calendar")
    history.visit("tags")
    XCTAssertEqual(history.previous(), "calendar")
    history.visit("calendar")
    XCTAssertEqual(history.previous(), "work")
    history.visit("work")
    history.finishSwitching()
    XCTAssertEqual(history.previous(), "tags")
    XCTAssertEqual(history.previous(), "calendar")
    history.finishSwitching()
    XCTAssertEqual(history.previous(), "work")
  }

  func testTwoSectionsKeepSwitchingBackAndForth() {
    var history = NavigationHistory(initial: "board")
    XCTAssertNil(history.previous())
    history.visit("calendar")
    for _ in 0..<5 {
      XCTAssertEqual(history.previous(), "board")
      history.visit("board")
      XCTAssertEqual(history.previous(), "calendar")
      history.visit("calendar")
    }
  }

  func testRepeatedBackStepsCycleThroughRecentSections() {
    var history = NavigationHistory(initial: "board")
    history.visit("work")
    history.visit("calendar")
    history.visit("tags")
    XCTAssertEqual(history.previous(), "calendar")
    history.visit("calendar")
    XCTAssertEqual(history.previous(), "work")
    history.visit("work")
    XCTAssertEqual(history.previous(), "board")
    XCTAssertEqual(history.previous(), "tags")
  }

  func testRecentSectionsAreUniqueAndManualNavigationStartsANewSequence() {
    var history = NavigationHistory(initial: "board")
    history.visit("work")
    history.visit("board")
    history.visit("calendar")
    XCTAssertEqual(history.previous(), "board")
    XCTAssertEqual(history.previous(), "work")
    history.visit("inbox")
    XCTAssertEqual(history.previous(), "work")
    XCTAssertEqual(history.previous(), "calendar")
    XCTAssertEqual(history.previous(), "board")
    XCTAssertEqual(history.previous(), "inbox")
  }
}
