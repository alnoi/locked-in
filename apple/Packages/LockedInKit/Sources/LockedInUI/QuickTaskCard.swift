import LockedInData
import LockedInDomain
import SwiftUI

struct QuickTaskScrollTarget: Hashable {
  var listID: UUID?
}

struct QuickTaskCard: View {
  @Bindable var model: AppModel
  var listID: UUID?
  var requiredTags: [UUID] = []
  var planForToday = false
  var reveal: () -> Void = {}
  @State private var title = ""
  @State private var tagIDs: [UUID] = []
  @State private var saving = false
  @State private var errorMessage: String?
  @FocusState private var focused: Bool
  private var active: Bool { focused || !title.isEmpty || !tagIDs.isEmpty }
  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      Circle().strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 2]))
        .foregroundStyle(.secondary.opacity(0.6)).frame(width: 17, height: 17).padding(.top, 2)
      VStack(alignment: .leading, spacing: 4) {
        TextField(focused ? "Название задачи" : "", text: $title, axis: .vertical)
          .lineLimit(1...)
          .fixedSize(horizontal: false, vertical: true)
          .textFieldStyle(.plain).font(.body.weight(.medium)).focused($focused)
          .accessibilityLabel("Новая задача в списке")
          .onSubmit { Task { await save(draft, keepFocus: true) } }
        if active {
          HStack(spacing: 8) {
            Menu {
              if model.snapshot.tags.isEmpty { Text("Пока нет тегов") }
              ForEach(model.snapshot.tags) { tag in
                Toggle(
                  tag.name,
                  isOn: Binding(
                    get: { selectedTags.contains(tag.id) },
                    set: { selected in
                      if selected {
                        tagIDs.append(tag.id)
                      } else {
                        tagIDs.removeAll { $0 == tag.id }
                      }
                    })
                ).disabled(requiredTags.contains(tag.id))
              }
            } label: {
              Group {
                if selectedTags.isEmpty {
                  Text("# тег").foregroundStyle(.secondary)
                } else {
                  TaskTagStyle.label(model.snapshot.tags.filter { selectedTags.contains($0.id) })
                }
              }.font(.caption).lineLimit(2)
            }.menuStyle(.borderlessButton).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
              Task { await save(draft, keepFocus: true) }
            } label: {
              Image(systemName: saving ? "ellipsis" : "arrow.up.circle.fill").font(.title3)
            }.buttonStyle(.plain).foregroundStyle(Color.accent)
              .disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
              .accessibilityLabel("Создать задачу")
          }
        }
        EditorFooter(message: errorMessage)
      }
    }.padding(.horizontal, 10).padding(.vertical, 8).frame(minHeight: 40)
      .background(Color.taskCardSurface, in: RoundedRectangle(cornerRadius: 12))
      .contentShape(RoundedRectangle(cornerRadius: 12))
      .onTapGesture { focused = true }
      .background {
        QuickTaskOutsideClick(enabled: active && !saving, outside: finishEditing).allowsHitTesting(
          false)
      }
      .background {
        GeometryReader { geometry in
          Color.clear.onChange(of: geometry.size.height) { _, _ in revealIfFocused() }
        }
      }
      .onChange(of: focused) { _, value in if value { revealIfFocused() } }
      .onChange(of: title.isEmpty) { _, empty in if empty { revealIfFocused() } }
      .disabled(!model.canEdit)
  }
  private func revealIfFocused() {
    guard focused else { return }
    // Wait for the growing editor and newly inserted tasks to finish layout.
    DispatchQueue.main.async { reveal() }
  }
  private var selectedTags: Set<UUID> { Set(tagIDs).union(requiredTags) }
  private var draft: TaskInput {
    TaskInput(
      title: title.trimmingCharacters(in: .whitespacesAndNewlines), listID: listID,
      plannedAt: planForToday ? .now : nil, tagIDs: Array(selectedTags))
  }
  private func finishEditing() {
    guard !saving else { return }
    let input = draft
    focused = false
    if input.title.isEmpty {
      title = ""
      tagIDs = []
      errorMessage = nil
    } else {
      Task { await save(input, keepFocus: false) }
    }
  }
  @MainActor private func save(_ input: TaskInput, keepFocus: Bool) async {
    guard !saving, !input.title.isEmpty else { return }
    saving = true
    defer { saving = false }
    do {
      try await model.mutate(.task(nil, input))
      if draft.title == input.title && Set(draft.tagIDs) == Set(input.tagIDs) {
        title = ""
        tagIDs = []
      }
      errorMessage = nil
      if keepFocus { focused = true }
    } catch { errorMessage = UserFacingErrors.message(error) }
  }
}
