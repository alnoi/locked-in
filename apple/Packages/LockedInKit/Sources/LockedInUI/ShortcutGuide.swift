import SwiftUI

// Keep this reference in sync with AppShortcut.match and the task/calendar handlers.
private struct ShortcutEntry: Identifiable {
  let action: String
  let keys: [String]
  var id: String { action }
}
private struct ShortcutGroup: Identifiable {
  let title: String
  let caption: String
  let entries: [ShortcutEntry]
  var id: String { title }
}

struct ShortcutGuide: View {
  private static let groups: [ShortcutGroup] = [
    ShortcutGroup(title: "Навигация", caption: "Когда открыт основной экран приложения.", entries: [
      ShortcutEntry(action: "Найти задачу", keys: ["⌘", "F"]),
      ShortcutEntry(action: "Новая задача · в «Сегодня» сразу на сегодня", keys: ["⌘", "T"]),
      ShortcutEntry(action: "Закрепить / скрыть боковую панель", keys: ["⌘", "S"]),
      ShortcutEntry(action: "Предыдущий раздел", keys: ["⌃", "Tab"]),
      ShortcutEntry(action: "Отменить последнее действие", keys: ["⌘", "Z"]),
    ]),
    ShortcutGroup(title: "Карточка задачи", caption: "Действуют в открытой карточке. Завершение, удаление и планирование — для уже созданной задачи.", entries: [
      ShortcutEntry(action: "Сохранить и закрыть", keys: ["↩"]),
      ShortcutEntry(action: "Закрыть карточку", keys: ["Esc"]),
      ShortcutEntry(action: "Завершить задачу", keys: ["⇧", "⌘", "↩"]),
      ShortcutEntry(action: "Удалить без подтверждения", keys: ["⌘", "⌫"]),
      ShortcutEntry(action: "Преобразовать / расформировать проект", keys: ["⇧", "⌘", "P"]),
      ShortcutEntry(action: "Добавить ссылку", keys: ["⌘", "L"]),
      ShortcutEntry(action: "Запланировать сейчас / снять планирование", keys: ["⌘", "P"]),
      ShortcutEntry(action: "Снять планирование", keys: ["⇧", "⌘", "⌫"]),
    ]),
    ShortcutGroup(title: "Календарь", caption: "Когда открыт календарь и курсор не находится в поле ввода.", entries: [
      ShortcutEntry(action: "Предыдущий / следующий период", keys: ["←", "→"]),
      ShortcutEntry(action: "Сегодня", keys: ["T"]),
      ShortcutEntry(action: "День", keys: ["1"]),
      ShortcutEntry(action: "Неделя", keys: ["2"]),
      ShortcutEntry(action: "Месяц", keys: ["3"]),
    ]),
  ]
  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(spacing: 12) {
        Image(systemName: "keyboard").font(.title2).foregroundStyle(Color.accent)
        Text("Сочетания для Mac. Работают и в русской раскладке.")
          .font(.callout).foregroundStyle(.secondary)
      }
      ForEach(Self.groups) { group in
        SettingsCard(title: group.title, caption: group.caption) {
          ForEach(Array(group.entries.enumerated()), id: \.element.id) { index, entry in
            if index > 0 { Divider() }
            HStack(spacing: 14) {
              Text(entry.action).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
              Spacer(minLength: 4)
              HStack(spacing: 4) {
                ForEach(Array(entry.keys.enumerated()), id: \.offset) { _, key in
                  Text(key).font(.system(size: 12, weight: .medium, design: .monospaced))
                    .frame(minWidth: 25, minHeight: 26)
                    .padding(.horizontal, key.count > 1 ? 5 : 0)
                    .background(Color.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.08)))
                }
              }.fixedSize()
            }.accessibilityElement(children: .combine)
          }
        }
      }
      Text("Удерживай Control и нажимай Tab, чтобы идти по недавно открытым разделам. Отпусти Control, чтобы закончить переключение. Enter сохраняет всю карточку и закрывает её, включая введённые ссылки и заметки.")
        .font(.caption).foregroundStyle(.secondary)
    }
  }
}
