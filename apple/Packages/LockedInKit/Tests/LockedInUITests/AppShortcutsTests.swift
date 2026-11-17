import SwiftUI
import XCTest
@testable import LockedInUI

final class AppShortcutsTests: XCTestCase {
  func testRequestedCommandBindingsWorkInsideAndOutsideTextFields() {
    let cases: [(String, EventModifiers, AppShortcut)] = [
      ("tab", .control, .previousSection), ("f", .command, .search), ("t", .command, .newInboxTask),
      ("s", .command, .sidebar), ("l", .command, .links),
      ("delete", .command, .delete), ("return", .command, .submit),
      ("delete", [.command, .shift], .unplan), ("return", [.command, .shift], .complete), ("p", [.command, .shift], .project),
    ]
    for (key, modifiers, expected) in cases {
      for editing in [true, false] {
        XCTAssertEqual(AppShortcut.match(key: key, modifiers: modifiers, editingText: editing), expected)
      }
    }
    XCTAssertEqual(AppShortcut.match(key: "escape", modifiers: [], editingText: true), .close)
  }

  func testCalendarKeysAndPlainEnterDoNotInterceptTextInput() {
    let cases: [(String, AppShortcut)] = [
      ("left", .previousPeriod), ("right", .nextPeriod), ("t", .today),
      ("1", .day), ("2", .week), ("3", .month), ("return", .submit),
    ]
    for (key, expected) in cases {
      XCTAssertEqual(AppShortcut.match(key: key, modifiers: [], editingText: false), expected)
      XCTAssertNil(AppShortcut.match(key: key, modifiers: [], editingText: true))
    }
    for key in ["f", "t", "s", "l", "p", "return", "delete"] {
      XCTAssertNil(AppShortcut.match(key: key, modifiers: [.control, .command], editingText: false))
    }
  }

  func testCommandBindingsUsePhysicalKeysAcrossKeyboardLayouts() {
    XCTAssertEqual(AppShortcut.key(code: 3, fallback: "а"), "f")
    XCTAssertEqual(AppShortcut.key(code: 17, fallback: "е"), "t")
    XCTAssertEqual(AppShortcut.key(code: 35, fallback: "з"), "p")
    XCTAssertEqual(AppShortcut.key(code: 0, fallback: "ф"), "ф")
    XCTAssertEqual(AppShortcut.key(code: 76, fallback: ""), "return")
  }
}
