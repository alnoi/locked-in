import LockedInDomain
import SwiftUI

struct ProfileView: View {
  @Bindable var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var emoji: String
  @State private var working = false
  @State private var closing = false
  @State private var message: String?
  @State private var avatarPicker = EmojiPickerSession()

  init(model: AppModel) {
    self.model = model
    _emoji = State(initialValue: model.profileUser?.avatarEmoji ?? "")
  }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 22) {
          HStack(spacing: 16) {
            ProfileAvatarButton(emoji: $emoji, session: avatarPicker)
            VStack(alignment: .leading, spacing: 5) {
              Text(model.profileUser?.username ?? "Профиль").font(.title2.weight(.semibold))
              Text("Личное пространство").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
          }
          ProfileStatisticsView(tasks: model.snapshot.tasks)
          if let message { Text(message).font(.callout).foregroundStyle(.red) }
          if !model.unsyncedTaskIDs.isEmpty {
            Text("Изменения без синхронизации сохранятся на этом устройстве до следующего входа в этот аккаунт.")
              .font(.caption).foregroundStyle(.secondary)
          }
        }.padding(24)
      }.navigationTitle("Профиль")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Закрыть", action: closeProfile).keyboardShortcut(.cancelAction) }
          ToolbarItemGroup(placement: .confirmationAction) {
            Button("Выйти из аккаунта", role: .destructive) { Task { await signOut() } }
              .buttonStyle(.borderedProminent).tint(.red)
            Button("Сохранить") { Task { await save() } }.disabled((!emoji.isEmpty && !ProfileEmoji.valid(emoji)) || emoji == model.profileUser?.avatarEmoji)
              .keyboardShortcut(.defaultAction)
          }
        }.disabled(working || model.isMutating || closing)
    }
    #if os(macOS)
    .frame(width: 500, height: 720)
    #endif
    .dismissOnOutsideClick(enabled: !working && !model.isMutating && !closing, perform: closeProfile)
    .submitOnEnter(enabled: !working && !model.isMutating && !closing) { Task { await save() } }
  }
  private func closeProfile() {
    guard !closing else { return }
    closing = true
    avatarPicker.close(afterDismiss: { dismiss() })
  }
  private func signOut() async {
    guard !working, !model.isMutating else { return }
    working = true
    defer { working = false }
    do { try await model.signOut(); closeProfile() }
    catch { message = model.friendly(error) }
  }
  private func save() async {
    guard !working, !model.isMutating else { return }
    guard emoji != model.profileUser?.avatarEmoji else { closeProfile(); return }
    working = true
    defer { working = false }
    do { try await model.updateAvatar(emoji); closeProfile() }
    catch { message = model.friendly(error) }
  }
}
