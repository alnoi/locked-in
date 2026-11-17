import Foundation

enum WebLinks {
  private static let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

  static func matches(in text: String) -> [NSTextCheckingResult] {
    let range = NSRange(text.startIndex..<text.endIndex, in: text)
    return detector?.matches(in: text, range: range).filter {
      guard let scheme = $0.url?.scheme?.lowercased() else { return false }
      return scheme == "http" || scheme == "https"
    } ?? []
  }

  static func attributed(_ text: String) -> AttributedString {
    var result = AttributedString()
    var cursor = text.startIndex
    for match in matches(in: text) {
      guard let range = Range(match.range, in: text), let url = match.url else { continue }
      result += AttributedString(String(text[cursor..<range.lowerBound]))
      var link = AttributedString(String(text[range]))
      link.link = url
      result += link
      cursor = range.upperBound
    }
    result += AttributedString(String(text[cursor...]))
    return result
  }
}
