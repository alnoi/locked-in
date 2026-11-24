import SwiftUI

public enum AppAccent: String, CaseIterable, Identifiable {
  case violet, blue, cyan, teal, green, amber, orange, pink, red, graphite
  public static let preferenceKey = "trackit.accentColor"
  public var id: Self { self }
  var title: String {
    switch self {
    case .violet: "Фиолетовый"
    case .blue: "Синий"
    case .cyan: "Голубой"
    case .teal: "Бирюзовый"
    case .green: "Зелёный"
    case .amber: "Золотой"
    case .orange: "Оранжевый"
    case .pink: "Розовый"
    case .red: "Красный"
    case .graphite: "Графитовый"
    }
  }
  private var hex: String {
    switch self {
    case .violet: "#6558E8"
    case .blue: "#3478F6"
    case .cyan: "#0891B2"
    case .teal: "#0D9488"
    case .green: "#258544"
    case .amber: "#B7790B"
    case .orange: "#D96716"
    case .pink: "#D33C89"
    case .red: "#D84949"
    case .graphite: "#667085"
    }
  }
  var color: Color { Color(hex: hex) }
  var brandHighlight: Color { self == .violet ? Color(hex: "#8174F3") : lightened(by: 0.22) }
  var buttonHighlight: Color { self == .violet ? Color(hex: "#796AF0") : lightened(by: 0.14) }
  private func lightened(by amount: Double) -> Color {
    let value = UInt32(hex.dropFirst(), radix: 16) ?? 0x6558E8
    func channel(_ shift: UInt32) -> Double {
      let component = Double((value >> shift) & 255) / 255
      return component + (1 - component) * amount
    }
    return Color(red: channel(16), green: channel(8), blue: channel(0))
  }
}

public extension View {
  func trackItAccent() -> some View { modifier(AppAccentAppearance()) }
}

private struct AppAccentAppearance: ViewModifier {
  @AppStorage(AppAccent.preferenceKey) private var accent: AppAccent = .violet
  func body(content: Content) -> some View {
    content.accentColor(accent.color).tint(accent.color)
  }
}

struct AccentColorSelection: View {
  @Binding var selected: AppAccent
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(selected.title).font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
        ForEach(AppAccent.allCases) { item in
          Button { selected = item } label: {
            Circle().fill(item.color).frame(width: 32, height: 32)
              .overlay {
                if selected == item {
                  Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                }
              }.padding(5)
              .overlay { Circle().strokeBorder(selected == item ? item.color.opacity(0.5) : .clear, lineWidth: 2) }
              .frame(maxWidth: .infinity).contentShape(Rectangle())
          }.buttonStyle(.plain).help(item.title)
            .accessibilityLabel(item.title + (item == .violet ? ", по умолчанию" : ""))
            .accessibilityAddTraits(selected == item ? .isSelected : [])
        }
      }
    }
  }
}
