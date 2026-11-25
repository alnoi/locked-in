import SwiftUI

public extension View {
  @MainActor func trackItTheme(_ theme: AppTheme) -> some View {
    modifier(AppThemeAppearance(theme: theme))
  }
}

@MainActor private struct AppThemeAppearance: ViewModifier {
  var theme: AppTheme
  #if os(macOS)
  @StateObject private var system = MacSystemTheme()
  #endif
  func body(content: Content) -> some View {
    #if os(macOS)
    let scheme = theme.colorScheme ?? system.colorScheme
    content.preferredColorScheme(scheme).environment(\.colorScheme, scheme)
    #else
    content.preferredColorScheme(theme.colorScheme)
    #endif
  }
}

#if os(macOS)
import AppKit

@MainActor private final class MacSystemTheme: ObservableObject {
  @Published private(set) var colorScheme: ColorScheme
  private var observation: NSKeyValueObservation?
  init() {
    colorScheme = Self.current
    observation = NSApplication.shared.observe(\.effectiveAppearance, options: [.new]) { [weak self] _, _ in
      Task { @MainActor [weak self] in
        guard let self else { return }
        let scheme = Self.current
        if colorScheme != scheme { colorScheme = scheme }
      }
    }
  }
  private static var current: ColorScheme {
    NSApplication.shared.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
  }
}
#endif
