import SwiftUI

struct BugReportButton: View {
  var model: AppModel
  @State private var presented = false
  var body: some View {
    Button { presented = true } label: {
      Image(systemName: "ladybug").font(.system(size: 14, weight: .regular))
        .foregroundStyle(.secondary).frame(width: 28, height: 28).contentShape(Circle())
    }.buttonStyle(.plain).help("Сообщить об ошибке")
      .accessibilityLabel("Сообщить об ошибке")
      .sheet(isPresented: $presented) { BugReportView(model: model).trackItAccent() }
  }
}

public extension View {
  func bugReportAccess(model: AppModel, reserveSpace: Bool = false) -> some View {
    modifier(BugReportAccess(model: model, reserveSpace: reserveSpace))
  }
}
private struct BugReportAccess: ViewModifier {
  var model: AppModel
  var reserveSpace: Bool
  func body(content: Content) -> some View {
    #if os(macOS)
    if !reserveSpace {
      content.overlay(alignment: .bottomTrailing) {
        BugReportButton(model: model).background(.ultraThinMaterial, in: Circle()).padding(12)
      }
    } else { VStack(spacing: 0) { content; footer } }
    #else
    VStack(spacing: 0) { content; footer }
    #endif
  }
  private var footer: some View {
    HStack { Spacer(); BugReportButton(model: model) }
      .padding(.horizontal, 14).frame(height: 30).background(.bar)
  }
}
