import Foundation

public enum BoardDragPayload: Equatable, Sendable {
  case list(UUID)
  case task(UUID)
  public init?(text: String) {
    let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if value.hasPrefix("locked-in-list:"),
      let id = UUID(uuidString: String(value.dropFirst("locked-in-list:".count)))
    {
      self = .list(id)
    } else if let id = UUID(uuidString: value) {
      self = .task(id)
    } else {
      return nil
    }
  }
  public var text: String {
    switch self {
    case .list(let id): return "locked-in-list:" + id.uuidString
    case .task(let id): return id.uuidString
    }
  }
}
