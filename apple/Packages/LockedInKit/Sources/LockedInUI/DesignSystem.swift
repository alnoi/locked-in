import LockedInDomain
import SwiftUI

extension Color {
  init(hex: String?) {
    let value =
      UInt32((hex ?? "#6366F1").replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x6366F1
    self.init(
      red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255)
  }
  static let accent = Color(hex: "#6558E8")
  static let taskCardSurface = Color.primary.opacity(0.085)
  static let mutedSurface = Color.primary.opacity(0.035)
}
struct TagPill: View {
  var tag: TagRecord
  var body: some View {
    Text("#" + tag.name).font(.caption.weight(.medium)).lineLimit(1)
      .padding(.horizontal, 8).padding(.vertical, 4)
      .foregroundStyle(Color(hex: tag.color)).background(
        Color(hex: tag.color).opacity(0.1), in: Capsule())
  }
}
struct EmptyState: View {
  var symbol: String
  var title: String
  var message: String
  var action: (() -> Void)?
  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: symbol).font(.system(size: 32, weight: .light)).foregroundStyle(
        Color.accent
      )
      .frame(width: 76, height: 76).background(
        Color.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 24))
      Text(title).font(.title3.bold())
      Text(message).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        .frame(maxWidth: 320)
      if let action {
        Button("Добавить задачу", action: action).buttonStyle(.borderedProminent).padding(.top, 4)
      }
    }.padding(30).frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
struct EditorFooter: View {
  var message: String?
  var body: some View {
    if let message {
      Label(message, systemImage: "exclamationmark.circle").font(.callout).foregroundStyle(.red)
        .padding(.vertical, 4)
    }
  }
}
struct TagSelection: View {
  var tags: [TagRecord]
  @Binding var selected: [UUID]
  var body: some View {
    if tags.isEmpty {
      Text("Создай теги в разделе «Теги».").font(.subheadline).foregroundStyle(.secondary)
    } else {
      LazyVGrid(
        columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading,
        spacing: 8
      ) {
        ForEach(tags) { tag in
          let included = selected.contains(tag.id)
          Button {
            if included { selected.removeAll { $0 == tag.id } } else { selected.append(tag.id) }
          } label: {
            HStack(spacing: 6) {
              Image(systemName: included ? "checkmark.circle.fill" : "circle")
              Text(tag.name).lineLimit(1)
              Spacer(minLength: 0)
            }.font(.callout).padding(8).foregroundStyle(Color(hex: tag.color))
              .background(
                Color(hex: tag.color).opacity(included ? 0.16 : 0.05),
                in: RoundedRectangle(cornerRadius: 9))
          }.buttonStyle(.plain).accessibilityLabel(tag.name).accessibilityValue(
            included ? "Выбран" : "Не выбран")
        }
      }
    }
  }
}
