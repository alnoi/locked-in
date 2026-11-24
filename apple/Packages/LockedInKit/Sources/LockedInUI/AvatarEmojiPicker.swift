import Observation
import SwiftUI

@Observable @MainActor
final class EmojiPickerSession {
  var isPresented = false
  @ObservationIgnored private var isVisible = false
  @ObservationIgnored private var completion: (() -> Void)?
  func close() { isPresented = false }
  func close(afterDismiss action: @escaping () -> Void) {
    let waitForDismissal = isVisible
    if waitForDismissal { completion = action }
    // Close the child immediately; keep the parent's normal dismissal animation.
    var transaction = Transaction(animation: nil)
    transaction.disablesAnimations = true
    withTransaction(transaction) { isPresented = false }
    if !waitForDismissal { DispatchQueue.main.async(execute: action) }
  }
  func didAppear() { isVisible = true }
  func didDisappear() {
    isVisible = false
    isPresented = false
    let action = completion
    completion = nil
    // Finish the popover's presentation update before dismissing its parent sheet.
    if let action { DispatchQueue.main.async(execute: action) }
  }
}

extension View {
  func avatarEmojiPicker(emoji: Binding<String>, session: EmojiPickerSession) -> some View {
    modifier(AvatarEmojiPickerPresentation(emoji: emoji, session: session))
  }
}

private struct AvatarEmojiPickerPresentation: ViewModifier {
  @Binding var emoji: String
  @Bindable var session: EmojiPickerSession
  private var arrowEdge: Edge {
    #if os(iOS)
    .top
    #else
    .bottom
    #endif
  }
  func body(content: Content) -> some View {
    content.popover(isPresented: $session.isPresented, attachmentAnchor: .rect(.bounds), arrowEdge: arrowEdge) {
      AvatarEmojiPicker(selected: emoji) { value in
        emoji = value
        session.close()
      }.presentationCompactAdaptation(.popover)
        .onAppear { session.didAppear() }
        .onDisappear { session.didDisappear() }
    }.onDisappear { session.close() }
  }
}

private struct AvatarEmoji: Decodable, Identifiable {
  var id: String { emoji }
  let emoji: String
  let name: String
  let category: String
  let search: String
  static let all: [AvatarEmoji] = {
    guard let url = Bundle.module.url(forResource: "AvatarEmojis", withExtension: "json"),
      let data = try? Data(contentsOf: url),
      let values = try? JSONDecoder().decode([AvatarEmoji].self, from: data) else { return [] }
    return values
  }()
}

private struct AvatarEmojiPicker: View {
  let selected: String
  var select: (String) -> Void
  @State private var query = ""
  @State private var category = "Smileys & Emotion"
  private var pickerSize: CGSize {
    #if os(iOS)
    CGSize(width: 300, height: 500)
    #else
    CGSize(width: 348, height: 420)
    #endif
  }
  private var columnCount: Int {
    #if os(iOS)
    6
    #else
    8
    #endif
  }
  private var cellHeight: CGFloat {
    #if os(iOS)
    42
    #else
    36
    #endif
  }
  private static let categories: [(id: String, title: String, icon: String)] = [
    ("Smileys & Emotion", "Эмоции", "face.smiling"),
    ("People & Body", "Люди и жесты", "hand.wave"),
    ("Animals & Nature", "Животные и природа", "leaf"),
    ("Food & Drink", "Еда", "fork.knife"),
    ("Travel & Places", "Места и транспорт", "car"),
    ("Activities", "Занятия", "soccerball"),
    ("Objects", "Предметы", "lightbulb"),
    ("Symbols", "Символы", "heart"),
    ("Flags", "Флаги", "flag"),
  ]
  private var matches: [AvatarEmoji] {
    let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
      .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
    return AvatarEmoji.all.filter { text.isEmpty ? $0.category == category : $0.search.contains(text) }
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Выбери эмоджи").font(.system(size: 15, weight: .semibold))
      HStack(spacing: 8) {
        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
        TextField("Поиск эмоджи", text: $query).textFieldStyle(.plain).autocorrectionDisabled()
          .onSubmit { if let first = matches.first { select(first.emoji) } }
        if !query.isEmpty {
          Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
            .buttonStyle(.plain).accessibilityLabel("Очистить поиск")
        }
      }.padding(10).background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
      HStack(spacing: 0) {
        ForEach(Self.categories, id: \.id) { item in
          Button { category = item.id; query = "" } label: {
            Image(systemName: item.icon).font(.system(size: 14))
              .frame(maxWidth: .infinity).frame(height: 32)
              .foregroundStyle(category == item.id && query.isEmpty ? Color.accent : .secondary)
              .background(category == item.id && query.isEmpty ? Color.accent.opacity(0.12) : .clear,
                in: RoundedRectangle(cornerRadius: 8))
              .contentShape(Rectangle())
          }.buttonStyle(.plain).help(item.title).accessibilityLabel(item.title)
            .accessibilityAddTraits(category == item.id && query.isEmpty ? .isSelected : [])
        }
      }
      ScrollView {
        let values = matches
        if values.isEmpty {
          ContentUnavailableView.search(text: query).frame(maxWidth: .infinity)
        } else {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: columnCount), spacing: 3) {
            ForEach(values) { item in
              Button { select(item.emoji) } label: {
                Text(item.emoji).font(.system(size: 25)).frame(maxWidth: .infinity).frame(height: cellHeight)
                  .background(selected == item.emoji ? Color.accent.opacity(0.16) : .clear,
                    in: RoundedRectangle(cornerRadius: 8))
                  .contentShape(RoundedRectangle(cornerRadius: 8))
              }.buttonStyle(.plain).help(item.name).accessibilityLabel(item.name)
                .accessibilityAddTraits(selected == item.emoji ? .isSelected : [])
            }
          }
        }
      }.id(category)
    }.padding(14).frame(width: pickerSize.width, height: pickerSize.height)
  }
}
