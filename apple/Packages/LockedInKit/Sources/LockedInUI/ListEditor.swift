import LockedInDomain
import SwiftUI

struct ListEditor: View {
    @Bindable var model: AppModel
    let presentation: ListPresentation
    @State private var input: ListInput
    @State private var message: String?
    @State private var confirmDelete = false
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    init(model: AppModel, presentation: ListPresentation) {
        self.model = model
        self.presentation = presentation
        _input = State(initialValue: presentation.input)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Название списка") { TextField("Например, В работе", text: $input.name) }
                Section {
                    Picker("Доска", selection: $input.boardID) {
                        ForEach(model.snapshot.owningBoards) { board in Text(board.name).tag(Optional(board.id)) }
                    }
                } footer: {
                    Text("Список — группа задач. Дочерние доски показывают этот же список с отфильтрованными задачами.")
                }
                if presentation.listID != nil {
                    Section { Button("Удалить список", role: .destructive) { confirmDelete = true } }
                }
                EditorFooter(message: message)
            }.onSubmit { Task { await save() } }.formStyle(.grouped).navigationTitle(presentation.listID == nil ? "Новый список" : "Настройки списка")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction).disabled(model.isMutating)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") { Task { await save() } }.keyboardShortcut(.defaultAction).disabled(
                            !model.canEditCollections || saving || input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }.confirmationDialog("Удалить список?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Удалить", role: .destructive) {
                        if let id = presentation.listID {
                            Task {
                                do {
                                    try await model.mutate(.deleteList(id))
                                    dismiss()
                                } catch { message = error.localizedDescription }
                            }
                        }
                    }
                } message: {
                    Text("Все задачи списка будут перемещены во «Входящие».")
                }
        }.onAppear { if input.boardID == nil { input.boardID = model.snapshot.generalBoard?.id } }
            .interactiveDismissDisabled()
            #if os(macOS)
                .frame(width: 500, height: 360)
            #endif
    }
    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        var value = input
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.boardID == nil { value.boardID = model.snapshot.generalBoard?.id }
        do {
            try TrackerRules.validate(value, id: presentation.listID, in: model.snapshot)
            try await model.mutate(.list(presentation.listID, value))
            dismiss()
        } catch { message = error.localizedDescription }
    }
}
