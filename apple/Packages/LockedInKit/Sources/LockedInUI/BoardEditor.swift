import LockedInData
import LockedInDomain
import SwiftUI

struct BoardEditor: View {
    @Bindable var model: AppModel
    let presentation: BoardPresentation
    @State private var input: BoardInput
    @State private var completionFilter: Int
    @State private var errorMessage: String?
    @State private var confirmDelete = false
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    init(model: AppModel, presentation: BoardPresentation) {
        self.model = model
        self.presentation = presentation
        _input = State(initialValue: presentation.input)
        _completionFilter = State(initialValue: presentation.input.filterCompleted.map { $0 ? 1 : 0 } ?? -1)
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("Название") { TextField("Например, Работа", text: $input.name) }
                if model.snapshot.boards.first(where: { $0.id == presentation.boardID })?.isGeneral != true {
                    Section {
                        Picker("Родительская доска", selection: $input.parentID) {
                            Text("Нет — основная доска").tag(UUID?.none)
                            ForEach(model.snapshot.boards.filter { $0.id != presentation.boardID }) {
                                Text($0.name).tag(Optional($0.id))
                            }
                        }
                    } footer: {
                        Text(
                            input.parentID == nil
                                ? "Основная доска содержит собственные списки задач."
                                : "Дочерняя доска наследует списки и теги родителя. Выбранные ниже теги дополнительно сужают фильтр.")
                    }
                }
                if input.parentID != nil {
                    Section("Фильтр по тегам · нужны все выбранные") {
                        TagSelection(tags: model.snapshot.tags, selected: $input.tagIDs)
                    }
                    Section("Выполнение") {
                        Picker("Показывать", selection: $completionFilter) {
                            Text("Все задачи").tag(-1)
                            Text("Незавершённые").tag(0)
                            Text("Завершённые").tag(1)
                        }
                    }
                }
                if let id = presentation.boardID,
                    model.snapshot.boards.first(where: { $0.id == id })?.isGeneral == false
                {
                    Section { Button("Удалить доску", role: .destructive) { confirmDelete = true } }
                }
                if errorMessage != nil { Section { EditorFooter(message: errorMessage) } }
            }.onSubmit { Task { await save() } }.formStyle(.grouped)
                .navigationTitle(presentation.boardID == nil ? "Новая доска" : "Настройки доски")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction).disabled(model.isMutating)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Сохранить") { Task { await save() } }.keyboardShortcut(.defaultAction).disabled(
                            !model.canEditCollections || saving || input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .confirmationDialog("Удалить доску?", isPresented: $confirmDelete, titleVisibility: .visible) {
                    Button("Удалить", role: .destructive) {
                        if let id = presentation.boardID {
                            Task {
                                do {
                                    try await model.mutate(.deleteBoard(id))
                                    dismiss()
                                } catch { errorMessage = UserFacingErrors.message(error) }
                            }
                        }
                    }
                }
        }.interactiveDismissDisabled(saving || model.isMutating || confirmDelete)
        .dismissOnOutsideClick(enabled: !saving && !model.isMutating && !confirmDelete)
        .submitOnEnter(enabled: !saving && !model.isMutating && !confirmDelete) { Task { await save() } }
            #if os(macOS)
                .frame(width: 500, height: 520)
            #endif
    }
    private func save() async {
        guard !saving else { return }
        saving = true
        defer { saving = false }
        var value = input
        value.name = value.name.trimmingCharacters(in: .whitespacesAndNewlines)
        value.filterCompleted = value.parentID == nil || completionFilter == -1 ? nil : completionFilter == 1
        if value.parentID == nil { value.tagIDs = [] }
        do {
            try TrackerRules.validate(value, id: presentation.boardID, in: model.snapshot)
            try await model.mutate(.board(presentation.boardID, value))
            dismiss()
        } catch { errorMessage = UserFacingErrors.message(error) }
    }
}
