import SwiftUI
#if os(iOS)
import UIKit
#endif

struct PlannerSidebarLayout<Sidebar: View, Detail: View>: View {
  @Binding var columnVisibility: NavigationSplitViewVisibility
  @Binding var compactColumn: NavigationSplitViewColumn
  private let hoverSidebar: Bool
  private let sidebar: Sidebar
  private let detail: Detail
  private let phoneScreen: PhoneScreen
  private let phoneDirection: CalendarPageDirection
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  init(columnVisibility: Binding<NavigationSplitViewVisibility>,
    compactColumn: Binding<NavigationSplitViewColumn>, hoverSidebar: Bool,
    phoneScreen: PhoneScreen = .section(.board), phoneDirection: CalendarPageDirection = CalendarPageDirection(),
    @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
    _columnVisibility = columnVisibility
    _compactColumn = compactColumn
    self.hoverSidebar = hoverSidebar
    self.phoneScreen = phoneScreen; self.phoneDirection = phoneDirection
    self.sidebar = sidebar()
    self.detail = detail()
  }
  var body: some View {
    #if os(macOS)
    let pinned = columnVisibility != .detailOnly
    let shown = pinned || hoverSidebar
    ZStack(alignment: .leading) {
      detail.frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(SidebarContentInset(inset: pinned ? 240 : 0))
      sidebar.frame(width: 240)
        .background {
          SidebarGlassBackground(cornerRadius: pinned ? 0 : 16)
            .padding(.top, pinned ? -2 : 0)
        }
        .modifier(SidebarActiveAppearance())
        .clipShape(RoundedRectangle(cornerRadius: pinned ? 0 : 16))
        .shadow(color: .black.opacity(pinned ? 0 : 0.2), radius: 16, x: 4, y: 3)
        .padding(.vertical, pinned ? 0 : 8).padding(.leading, pinned ? 0 : 8)
        .offset(x: shown ? 0 : -256)
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(shown)
        .accessibilityHidden(!shown)
        .zIndex(1)
    }.clipped()
    #else
    if UIDevice.current.userInterfaceIdiom == .phone {
      ZStack {
        if compactColumn == .sidebar {
          NavigationStack { sidebar }.id(phoneScreen).transition(phoneTransition)
        } else {
          detail.id(phoneScreen).transition(phoneTransition)
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: phoneScreen)
    } else {
      NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
        sidebar
      } detail: { detail }
    }
    #endif
  }
  private var phoneTransition: AnyTransition {
    reduceMotion ? .opacity : .asymmetric(
      insertion: .modifier(active: CalendarPageSlide(progress: 1, direction: phoneDirection),
        identity: CalendarPageSlide(progress: 0, direction: phoneDirection)),
      removal: .modifier(active: CalendarPageSlide(progress: -1, direction: phoneDirection),
        identity: CalendarPageSlide(progress: 0, direction: phoneDirection)))
  }
}

#if os(macOS)
import AppKit

private struct SidebarActiveAppearance: ViewModifier {
  @ViewBuilder func body(content: Content) -> some View {
    if #available(macOS 15, *) {
      content
        .environment(\.appearsActive, true)
        .materialActiveAppearance(.active)
    } else {
      content.environment(\.appearsActive, true)
    }
  }
}

private struct SidebarContentInset: ViewModifier {
  var inset: CGFloat
  @ViewBuilder func body(content: Content) -> some View {
    if #available(macOS 26, *) {
      content.safeAreaPadding(.leading, inset)
    } else {
      content.padding(.leading, inset)
    }
  }
}

private struct SidebarGlassBackground: View {
  @Environment(\.colorScheme) private var colorScheme
  private var tint: Color {
    colorScheme == .dark
      ? Color(red: 0.11, green: 0.11, blue: 0.12)
      : Color(red: 0.95, green: 0.95, blue: 0.96)
  }
  var cornerRadius: CGFloat
  var body: some View {
    if #available(macOS 26, *) {
      Color.clear.glassEffect(
        .regular.tint(tint.opacity(0.8)),
        in: RoundedRectangle(cornerRadius: cornerRadius))
    } else {
      SidebarVisualEffect()
        .overlay(tint.opacity(0.85))
    }
  }
}
private struct SidebarVisualEffect: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    view.material = .popover
    view.blendingMode = .withinWindow
    view.state = .active
    return view
  }
  func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}
#endif
