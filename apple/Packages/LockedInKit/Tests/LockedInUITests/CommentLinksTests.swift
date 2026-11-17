import Foundation
import LockedInDomain
import XCTest
@testable import LockedInUI

final class CommentLinksTests: XCTestCase {
  func testLinksRemainClickableWithoutChangingCommentTextOrLineBreaks() {
    let text = "Задача 👀: https://example.com/docs?q=one&mode=two.\nЕщё www.apple.com и https://example.org/path#section"
    let attributed = WebLinks.attributed(text)
    XCTAssertEqual(String(attributed.characters), text)
    XCTAssertEqual(attributed.runs.compactMap { $0.link?.absoluteString }, [
      "https://example.com/docs?q=one&mode=two", "https://www.apple.com", "https://example.org/path#section",
    ])
  }

  func testNonWebAddressesDoNotBecomeTaskLinks() {
    for text in ["Обычный комментарий", "Напиши hello@example.com", "file:///tmp/notes.txt", "javascript:alert(1)"] {
      XCTAssertTrue(TaskLinks(stored: text).urls.isEmpty)
      XCTAssertTrue(WebLinks.attributed(text).runs.allSatisfy { $0.link == nil })
    }
  }
}
