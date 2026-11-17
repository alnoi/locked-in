import Foundation
import XCTest
@testable import LockedInUI

final class TaskLinksTests: XCTestCase {
  func testAddressesAreNormalizedAndInvalidInputCannotBeSaved() throws {
    for (input, expected) in [
      ("example.com/path?q=one#section", "https://example.com/path?q=one#section"),
      ("  https://example.org/page  ", "https://example.org/page"),
      ("http://localhost:8080/test", "http://localhost:8080/test"),
    ] {
      XCTAssertEqual(TaskLinks.url(input)?.absoluteString, expected)
    }
    for invalid in ["Просто заметка", "hello", "hello@example.com", "javascript:alert(1)", "file:///tmp/file", "https://"] {
      var links = TaskLinks(stored: nil)
      XCTAssertThrowsError(try links.append(invalid))
      XCTAssertTrue(links.urls.isEmpty)
    }
  }

  func testMultipleLinksKeepOrderAndUnconfirmedDraftIsIncludedOnSave() throws {
    var links = TaskLinks(stored: nil)
    try links.append("first.example/path")
    try links.append("https://first.example/path")
    let stored = try links.stored(adding: "second.example/path")
    let restored = TaskLinks(stored: stored)
    XCTAssertEqual(restored.urls.map(\.absoluteString), ["https://first.example/path", "https://second.example/path"])
    XCTAssertEqual(restored.urls.first?.host, "first.example")
    XCTAssertNil(restored.legacyNote)
    XCTAssertThrowsError(try links.stored(adding: "не ссылка"))
  }

  func testExistingNotesSurviveURLChangesAndRemovingLastLinkClearsTheField() throws {
    var links = TaskLinks(stored: "Важная заметка\nhttps://example.com/path\nЕщё текст 👀")
    let note = try XCTUnwrap(links.legacyNote)
    XCTAssertTrue(note.contains("Важная заметка"))
    XCTAssertTrue(note.contains("Ещё текст 👀"))
    links.urls.removeAll()
    try links.append("new.example")
    let restored = TaskLinks(stored: try links.stored())
    XCTAssertEqual(restored.urls.first?.host, "new.example")
    XCTAssertEqual(restored.legacyNote, note)
    var onlyLinks = TaskLinks(stored: "https://example.com")
    onlyLinks.urls.removeAll()
    XCTAssertNil(try onlyLinks.stored())
  }
}
