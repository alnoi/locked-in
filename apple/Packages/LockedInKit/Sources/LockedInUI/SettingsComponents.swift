import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
  case general, notifications, shortcuts, connection
  var id: Self { self }
  var title: String {
    switch self {
    case .general: "Основные"
    case .notifications: "Уведомления"
    case .shortcuts: "Сочетания клавиш"
    case .connection: "Подключение"
    }
  }
  var symbol: String {
    switch self {
    case .general: "slider.horizontal.3"
    case .notifications: "bell.badge"
    case .shortcuts: "command"
    case .connection: "network"
    }
  }
  var subtitle: String {
    switch self {
    case .general: "Твой ритм и внешний вид."
    case .notifications: "Нужное напоминание в нужный момент."
    case .shortcuts: "Меньше кликов. Больше сделанного."
    case .connection: "Где живут и синхронизируются твои планы."
    }
  }
}

struct SettingsCard<Content: View>: View {
  var title: String
  var caption: String? = nil
  @ViewBuilder var content: () -> Content
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 16, content: content)
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.055)))
      if let caption { Text(caption).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 2) }
    }
  }
}

struct SettingsTimeRow: View {
  var title: String
  var symbol: String
  @Binding var value: Date
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: symbol).frame(width: 20).foregroundStyle(.secondary)
      Text(title)
      Spacer(minLength: 8)
      #if os(macOS)
      DatePicker(title, selection: $value, displayedComponents: .hourAndMinute)
        .labelsHidden().datePickerStyle(.field).fixedSize()
      #else
      DatePicker(title, selection: $value, displayedComponents: .hourAndMinute)
        .labelsHidden().datePickerStyle(.compact)
      #endif
    }
  }
}
