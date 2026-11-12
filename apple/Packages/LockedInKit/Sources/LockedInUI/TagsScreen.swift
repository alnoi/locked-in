import SwiftUI
import LockedInDomain

struct TagsScreen: View {
    @Bindable var model: AppModel
    var select: (UUID) -> Void
    @State private var editor: TagPresentation?
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 6) { Text("Маленькие метки. Больше порядка.").font(.title2.bold()); Text("Группируй задачи и создавай доски с фильтрами.").foregroundStyle(.secondary) }
                Spacer()
                Button { editor = TagPresentation() } label: { Label("Новый тег", systemImage: "plus") }.buttonStyle(.borderedProminent).disabled(!model.canEdit)
            }.padding([.horizontal, .top], 24)
            if model.snapshot.tags.isEmpty { EmptyState(symbol: "number", title: "У всего будет своя метка", message: "Создай первый тег: например, срочно, дом или backend.") }
            else {
                List {
                    ForEach(model.snapshot.tags.sorted { $0.name < $1.name }) { tag in
                        HStack {
                            Button { select(tag.id) } label: { HStack { TagPill(tag: tag); Spacer(); Text("\(model.snapshot.tasks.filter { $0.tagIDs.contains(tag.id) && !$0.completed }.count)").foregroundStyle(.secondary) } }.buttonStyle(.plain)
                            Button { editor = TagPresentation(id: tag.id, name: tag.name, color: tag.color ?? "#6558E8") } label: { Image(systemName: "pencil") }.buttonStyle(.borderless).accessibilityLabel("Изменить тег " + tag.name)
                        }.padding(.vertical, 8)
                    }
                }.listStyle(.plain)
            }
        }.sheet(item: $editor) { TagEditor(model: model, presentation: $0) }
    }
}
private struct TagPresentation: Identifiable { var id: UUID = UUID(); var name = ""; var color = "#6558E8" }
private struct TagEditor: View {
    @Bindable var model: AppModel
    let presentation: TagPresentation
    @State private var name: String
    @State private var color: String
    @State private var message: String?
    @State private var confirmDelete = false
    @Environment(\.dismiss) private var dismiss
    private let colors = ["#6558E8", "#3B82F6", "#10B981", "#F59E0B", "#EF4444", "#EC4899", "#64748B"]
    init(model: AppModel, presentation: TagPresentation) { self.model = model; self.presentation = presentation; _name = State(initialValue: presentation.name); _color = State(initialValue: presentation.color) }
    private var exists: Bool { model.snapshot.tags.contains { $0.id == presentation.id } }
    var body: some View {
        NavigationStack {
            Form {
                Section("Название") { TextField("Например, срочно", text: $name) }
                Section("Цвет") {
                    HStack { ForEach(colors, id: \.self) { value in Button { color = value } label: { Circle().fill(Color(hex: value)).frame(width: 28, height: 28).overlay { if color == value { Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white) } } }.buttonStyle(.plain).accessibilityLabel("Цвет " + value) } }
                }
                if exists { Section { Button("Удалить тег", role: .destructive) { confirmDelete = true } } }
                EditorFooter(message: message)
            }.formStyle(.grouped).navigationTitle(exists ? "Изменить тег" : "Новый тег")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() }.disabled(model.isMutating) }
                    ToolbarItem(placement: .confirmationAction) { Button("Сохранить") { Task { do { try await model.mutate(.tag(exists ? presentation.id : nil, name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color)); dismiss() } catch { message = error.localizedDescription } } }.disabled(!model.canEdit || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
                .confirmationDialog("Удалить тег?", isPresented: $confirmDelete, titleVisibility: .visible) { Button("Удалить", role: .destructive) { Task { do { try await model.mutate(.deleteTag(presentation.id)); dismiss() } catch { message = error.localizedDescription } } } }
        }.interactiveDismissDisabled()
        #if os(macOS)
        .frame(width: 430, height: 340)
        #endif
    }
}
