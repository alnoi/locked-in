import SwiftUI

struct TaskLinksField: View {
  @Binding var links: TaskLinks
  @Binding var draft: String
  var focusRequest = 0
  @FocusState private var focused: Bool
  var onSave: (TaskLinks) async throws -> Void = { _ in }
  @State private var message: String?
  @State private var isSaving = false

  var body: some View {
    VStack(spacing: 0) {
      ForEach(Array(links.urls.enumerated()), id: \.offset) { _, url in
        HStack(spacing: 10) {
          Image(systemName: "link").foregroundStyle(Color.accent)
            .frame(width: 28, height: 28).background(Color.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
          Link(destination: url) {
            VStack(alignment: .leading, spacing: 3) {
              Text(url.host ?? url.absoluteString).font(.callout.weight(.medium)).foregroundStyle(.primary)
              Text(url.absoluteString).font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
          }.buttonStyle(.plain).help(url.absoluteString)
          Button {
            Task { await remove(url) }
          } label: {
            Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
              .foregroundStyle(.secondary).frame(width: 24, height: 24).contentShape(Rectangle())
          }.buttonStyle(.plain).disabled(isSaving).accessibilityLabel("Удалить ссылку")
        }.padding(12)
        Divider().padding(.leading, 14)
      }
      HStack(spacing: 10) {
        Image(systemName: "link.badge.plus").foregroundStyle(.secondary).frame(width: 28)
        TextField("Добавить ссылку", text: $draft)
          .textFieldStyle(.plain).autocorrectionDisabled().focused($focused)
          #if os(iOS)
          .keyboardType(.URL).textInputAutocapitalization(.never)
          #endif
          .onSubmit { Task { await add() } }.disabled(isSaving).accessibilityIdentifier("task-url-input")
        if !draft.isEmpty {
          Button { Task { await add() } } label: {
            Image(systemName: "plus.circle.fill").foregroundStyle(Color.accent)
              .frame(width: 24, height: 24).contentShape(Rectangle())
          }.buttonStyle(.plain).disabled(isSaving).accessibilityLabel("Добавить ссылку")
        }
      }.padding(12)
      if let message {
        Text(message).font(.caption).foregroundStyle(.red)
          .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 14).padding(.bottom, 12)
      }
    }.onChange(of: draft) { _, _ in message = nil }
      .onChange(of: focusRequest) { _, _ in focused = true }
      .submitScope()
  }

  private func remove(_ url: URL) async {
    guard !isSaving, let index = links.urls.firstIndex(of: url) else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      var updated = links
      updated.urls.remove(at: index)
      try await onSave(updated)
      links = updated
      message = nil
    } catch { message = error.localizedDescription }
  }

  private func add() async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }
    do {
      var updated = links
      try updated.append(draft)
      try await onSave(updated)
      links = updated
      draft = ""
      message = nil
    } catch { message = error.localizedDescription }
  }
}
