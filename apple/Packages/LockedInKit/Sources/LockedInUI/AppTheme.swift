import SwiftUI

public enum AppTheme: String, CaseIterable, Identifiable {
  case light, dark, system

  public static let preferenceKey = "trackit.appearance"
  public var id: String { rawValue }
  public var colorScheme: ColorScheme? {
    switch self {
    case .light: return .light
    case .dark: return .dark
    case .system: return nil
    }
  }
  var title: String {
    switch self {
    case .light: return "Светлая"
    case .dark: return "Тёмная"
    case .system: return "Как в системе"
    }
  }
  var symbol: String {
    switch self {
    case .light: return "circle"
    case .dark: return "circle.fill"
    case .system: return "circle.lefthalf.filled"
    }
  }
}
