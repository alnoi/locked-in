import Foundation
import LockedInDomain

struct TaskLinks {
  var urls: [URL]
  let legacyNote: String?

  init(stored: String?) {
    let text = stored ?? ""
    let matches = WebLinks.matches(in: text)
    urls = matches.compactMap(\.url)
    let remainder = NSMutableString(string: text)
    for match in matches.reversed() { remainder.deleteCharacters(in: match.range) }
    let note = (remainder as String).trimmingCharacters(in: .whitespacesAndNewlines)
    legacyNote = note.isEmpty ? nil : note
  }

  static func url(_ text: String) -> URL? {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil else { return nil }
    let explicitScheme = value.contains("://")
    guard let components = URLComponents(string: explicitScheme ? value : "https://" + value),
      let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
      let host = components.host, !host.isEmpty,
      explicitScheme || ((host.contains(".") || host == "localhost") && components.user == nil),
      let url = components.url
    else { return nil }
    return url
  }

  mutating func append(_ text: String) throws {
    guard let url = Self.url(text) else {
      throw TrackerError.validation("Введи корректную ссылку, например example.com или https://example.com.")
    }
    if !urls.contains(url) { urls.append(url) }
  }

  func stored(adding draft: String = "") throws -> String? {
    var links = self
    if !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { try links.append(draft) }
    let parts = links.urls.map(\.absoluteString) + (legacyNote.map { [$0] } ?? [])
    return parts.isEmpty ? nil : parts.joined(separator: "\n")
  }
}
