import LockedInDomain
import SwiftUI

struct ProfileAvatar: View {
  var emoji: String
  var size: CGFloat
  var body: some View {
    Group {
      if emoji.isEmpty {
        Image(systemName: "person.fill").font(.system(size: size * 0.48, weight: .regular))
          .foregroundStyle(.secondary.opacity(0.65))
      } else { Text(emoji).font(.system(size: size * 0.65)) }
    }.frame(width: size, height: size)
      .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: size * 0.3))
      .accessibilityHidden(true)
  }
}

struct AvatarSelectionRow: View {
  @Binding var emoji: String
  var surface: Color = Color.primary.opacity(0.035)
  @State private var pickerSession = EmojiPickerSession()
  var body: some View {
    Button { pickerSession.isPresented.toggle() } label: {
      HStack(spacing: 14) {
        ProfileAvatar(emoji: emoji, size: 44)
        VStack(alignment: .leading, spacing: 4) {
          Text("Твоя аватарка").font(.system(size: 13, weight: .medium))
          Text(emoji.isEmpty ? "Необязательно · выбрать эмоджи" : "Нажми, чтобы сменить эмоджи")
            .font(.caption).foregroundStyle(.secondary)
        }
        Spacer(minLength: 8)
        Image(systemName: "face.smiling").font(.system(size: 18)).foregroundStyle(.secondary)
      }.padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }.buttonStyle(.plain)
      .avatarEmojiPicker(emoji: $emoji, session: pickerSession)
      .accessibilityLabel("Выбрать эмоджи для аватарки")
      .accessibilityValue(emoji.isEmpty ? "Не выбрана" : emoji)
      .contextMenu {
        if !emoji.isEmpty { Button("Убрать аватарку", systemImage: "person.crop.circle") { emoji = "" } }
      }
  }
}

struct ProfileAvatarButton: View {
  @Binding var emoji: String
  var session: EmojiPickerSession
  var body: some View {
    Button { session.isPresented.toggle() } label: {
      ProfileAvatar(emoji: emoji, size: 64)
        .overlay(alignment: .bottomTrailing) {
          Image(systemName: "pencil").font(.system(size: 9, weight: .semibold))
            .foregroundStyle(Color.accent).frame(width: 20, height: 20)
            .background(.regularMaterial, in: Circle())
        }
        .contentShape(RoundedRectangle(cornerRadius: 19))
    }.buttonStyle(.plain)
      .avatarEmojiPicker(emoji: $emoji, session: session)
      .accessibilityLabel("Изменить аватарку")
      .accessibilityValue(emoji.isEmpty ? "Не выбрана" : emoji)
      .help("Изменить аватарку")
      .contextMenu {
        if !emoji.isEmpty { Button("Убрать аватарку", systemImage: "person.crop.circle") { emoji = "" } }
      }
  }
}
