// xcode: set sdk=iOS

import SwiftUI
import SwiftData

struct TaskEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State var draft: TaskDraft
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Задача") {
                    TextField("Что нужно сделать?", text: $draft.title, axis: .vertical)
                        .lineLimit(1...4).focused($titleFocused)
                }
                Section("Время в календаре") {
                    DatePicker("Начало", selection: $draft.start)
                    Picker("Длительность", selection: $draft.duration) {
                        ForEach([15, 30, 45, 60, 90, 120, 180, 240, 480], id: \.self) { minutes in
                            Text(minutes < 60 ? "\(minutes) мин" : minutes % 60 == 0 ? "\(minutes / 60) ч" : "\(minutes / 60) ч \(minutes % 60) мин").tag(minutes)
                        }
                    }
                    LabeledContent("Окончание", value: draft.start.addingTimeInterval(Double(draft.duration) * 60).formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                if draft.task != nil {
                    Section { Button("Удалить задачу", role: .destructive) { confirmDelete = true } }
                }
                if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
            }
            .formStyle(.grouped)
            .navigationTitle(draft.task == nil ? "Новая задача" : "Редактирование")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить", action: save)
                        .disabled(draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .confirmationDialog("Удалить задачу?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    if let task = draft.task { context.delete(task) }
                    persist()
                }
            }
            .onAppear { titleFocused = draft.task == nil }
        }
        #if os(macOS)
        .frame(width: 460, height: 430)
        #endif
        .interactiveDismissDisabled()
    }
    private func save() {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        if let task = draft.task {
            task.title = title
            task.start = draft.start
            task.duration = draft.duration
        } else {
            context.insert(PlannerTask(title: title, start: draft.start, duration: draft.duration))
        }
        persist()
    }
    private func persist() {
        do { try context.save(); dismiss() }
        catch { context.rollback(); errorMessage = "Не удалось сохранить изменения: \(error.localizedDescription)" }
    }
}
