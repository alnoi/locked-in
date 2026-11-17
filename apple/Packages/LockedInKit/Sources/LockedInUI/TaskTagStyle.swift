import LockedInDomain
import SwiftUI

enum TaskTagStyle {
  static func color(_ task: TaskRecord, tags: [TagRecord]) -> Color {
    guard let hex = tags.first(where: { task.tagIDs.contains($0.id) })?.color else { return .gray }
    return Color(hex: hex)
  }
  static func label(_ tags: [TagRecord]) -> Text {
    tags.enumerated().reduce(Text("")) { text, item in
      text + Text((item.offset == 0 ? "" : "  ") + "#" + item.element.name)
        .foregroundColor(item.element.color.map { Color(hex: $0) } ?? .gray)
    }
  }
}
