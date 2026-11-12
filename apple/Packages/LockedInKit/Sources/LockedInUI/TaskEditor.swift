import LockedInData
import LockedInDomain
import SwiftUI

struct TaskEditor: View {
  @Bindable var model: AppModel
  let presentation: TaskPresentation
  private let close: (() -> Void)?
  @Environment(\.dismiss) private var presentationDismiss
  @Environment(\.openURL) private var openURL
  @State private var reminderMode: ReminderMode
  @State private var reminderMinutesBefore: Int
  @State private var reminderHint: String?
  @State private var requestingPermission = false
  @State private var showPermissionSettings = false
  @State private var input: TaskInput
  @State private var hasDeadline: Bool
  @State private var hasDeadlineTime: Bool
  @State private var deadline: Date
  @State private var hasPlan: Bool
  @State private var planned: Date
  @State private var hasDuration: Bool
  @State private var duration: Int
  @State private var errorMessage: String?
  @State private var confirmDelete = false
  @State private var comment = ""
  @State private var editingCommentID: UUID?
  @State private var child: TaskPresentation?
  @FocusState private var titleFocused: Bool
  init(model: AppModel, presentation: TaskPresentation, close: (() -> Void)? = nil) {
    self.model = model
    self.presentation = presentation
    self.close = close
    _reminderMode = State(initialValue: presentation.input.reminderMode ?? .none)
    _reminderMinutesBefore = State(initialValue: presentation.input.reminderMinutesBefore ?? 0)
    _input = State(initialValue: presentation.input)
    _hasDeadline = State(
      initialValue: presentation.input.deadlineAt != nil || presentation.input.deadlineDate != nil
        || presentation.taskID == nil)
    _hasDeadlineTime = State(initialValue: presentation.input.deadlineAt != nil)
    _deadline = State(
      initialValue: presentation.input.deadlineAt ?? presentation.input.deadlineDate.flatMap(
        DateOnly.parse) ?? .now)
    _hasPlan = State(initialValue: presentation.input.plannedAt != nil)
    _planned = State(initialValue: presentation.input.plannedAt ?? .now)
    _hasDuration = State(initialValue: presentation.input.durationMinutes != nil)
    _duration = State(initialValue: presentation.input.durationMinutes ?? 60)
  }
  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          inspectorGroup {
            TextField("Название задачи", text: $input.title, axis: .vertical)
              .font(.system(size: 23, weight: .semibold, design: .rounded)).lineLimit(1...4)
              .textFieldStyle(.plain).focused($titleFocused).accessibilityIdentifier("task-title")
              .padding(14)
            groupDivider
            TextField(
              "Заметки и URL",
              text: Binding(
                get: { input.description ?? "" }, set: { input.description = $0.isEmpty ? nil : $0 }
              ), axis: .vertical
            )
            .textFieldStyle(.plain).foregroundStyle(.secondary).lineLimit(1...5).padding(14)
          }
          inspectorSection("Дата и время") {
            inspectorRow("Дата", symbol: "calendar") {
              Toggle("Дата", isOn: $hasDeadline).labelsHidden().toggleStyle(.switch).controlSize(
                .small)
            }
            if hasDeadline {
              DatePicker("Дата дедлайна", selection: $deadline, displayedComponents: [.date])
                .datePickerStyle(.compact).labelsHidden().padding(.horizontal, 14).padding(
                  .bottom, 10)
              Text(deadline.formatted(.dateTime.day().month(.wide).year())).font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14).padding(.bottom, 10)
            }
            groupDivider
            inspectorRow("Время", symbol: "clock") {
              Toggle(
                "Время",
                isOn: Binding(
                  get: { hasDeadlineTime },
                  set: {
                    hasDeadlineTime = $0
                    if $0 { hasDeadline = true }
                  })
              )
              .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            if hasDeadlineTime {
              timePicker("Время дедлайна", selection: $deadline).padding(.horizontal, 14).padding(
                .bottom, 10)
            }
            groupDivider
            inspectorRow("Напоминание", symbol: reminderMode.symbol) { reminderControls }
            reminderFeedback.padding(.horizontal, 14)
          }
          inspectorSection("Организация") {
            inspectorRow("Список", symbol: "list.bullet") {
              Picker("Список", selection: $input.listID) {
                Text("Входящие").tag(UUID?.none)
                ForEach(model.snapshot.rootLists) { Text($0.name).tag(Optional($0.id)) }
              }.labelsHidden().fixedSize()
            }
            groupDivider
            inspectorRow("Теги", symbol: "number") {
              Menu {
                if model.snapshot.tags.isEmpty { Text("Пока нет тегов") }
                ForEach(model.snapshot.tags) { tag in
                  Toggle(
                    tag.name,
                    isOn: Binding(
                      get: { input.tagIDs.contains(tag.id) },
                      set: { selected in
                        if selected {
                          input.tagIDs.append(tag.id)
                        } else {
                          input.tagIDs.removeAll { $0 == tag.id }
                        }
                      }))
                }
              } label: {
                Text(input.tagIDs.isEmpty ? "Выбрать" : "Выбрано: \(input.tagIDs.count)")
                  .foregroundStyle(.secondary)
              }
              .menuStyle(.borderlessButton).fixedSize()
            }
            if !input.tagIDs.isEmpty {
              Text(
                model.snapshot.tags.filter { input.tagIDs.contains($0.id) }.map { "#" + $0.name }
                  .joined(separator: "  ")
              )
              .font(.caption).foregroundStyle(Color.accent).padding(.horizontal, 14).padding(
                .bottom, 12)
            }
            if !hasChildren {
              groupDivider
              inspectorRow("Проект", symbol: "square.stack") {
                Picker("Проект", selection: $input.parentID) {
                  Text("Без проекта").tag(UUID?.none)
                  ForEach(
                    model.snapshot.tasks.filter {
                      $0.parentID == nil && $0.id != presentation.taskID
                    }
                  ) { Text($0.title).tag(Optional($0.id)) }
                }.labelsHidden().frame(maxWidth: 175, alignment: .trailing)
              }
            }
          }
          inspectorSection("Планирование") {
            inspectorRow("В календаре", symbol: "calendar.badge.clock") {
              Toggle("В календаре", isOn: $hasPlan).labelsHidden().toggleStyle(.switch).controlSize(
                .small)
            }
            if hasPlan { planningFields.padding(.horizontal, 14).padding(.bottom, 12) }
            groupDivider
            inspectorRow("Длительность", symbol: "hourglass") {
              if hasDuration {
                TextField("Минут", value: $duration, format: .number).textFieldStyle(.plain)
                  .multilineTextAlignment(.trailing).frame(width: 45)
                Text("мин").foregroundStyle(.secondary)
              }
              Toggle("Длительность", isOn: $hasDuration).labelsHidden().toggleStyle(.switch)
                .controlSize(.small)
            }
          }
          if let taskID = presentation.taskID {
            subtasks(taskID)
            comments(taskID)
            Button("Удалить задачу", role: .destructive) { confirmDelete = true }
              .buttonStyle(.plain).font(.subheadline).padding(.horizontal, 12)
          }
          EditorFooter(message: errorMessage)
        }.padding(12)
      }
      Divider().opacity(0.5)
      HStack {
        Button("Отмена") { dismissEditor() }.buttonStyle(.plain).foregroundStyle(.secondary)
          .disabled(
            model.isMutating)
        Spacer()
        Button(isCreating ? "Создать" : "Сохранить") { Task { await save() } }
          .buttonStyle(.borderedProminent).controlSize(.small)
          .disabled(
            !model.canEdit || requestingPermission
              || input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .keyboardShortcut(.return, modifiers: .command)
      }.padding(14)
    }
    .modifier(TaskInspectorGlass())
    .onChange(of: hasDeadline) { _, enabled in if !enabled { hasDeadlineTime = false } }
    .confirmationDialog("Удалить задачу?", isPresented: $confirmDelete, titleVisibility: .visible) {
      Button("Удалить", role: .destructive) {
        guard let id = presentation.taskID else { return }
        Task {
          do {
            try await model.mutate(.deleteTask(id))
            dismissEditor()
          } catch { errorMessage = error.localizedDescription }
        }
      }
    }
    .sheet(item: $child) { TaskEditor(model: model, presentation: $0) }
    .onAppear { titleFocused = isCreating }
    #if os(macOS)
      .frame(width: 380, height: 620)
    #else
      .presentationDetents([.large]).presentationDragIndicator(.visible)
    #endif
  }
  private func dismissEditor() {
    if let close { close() } else { presentationDismiss() }
  }
  private var isCreating: Bool { presentation.taskID == nil }
  private var groupDivider: some View {
    Divider().padding(.leading, 46).padding(.trailing, 14).opacity(0.6)
  }
  private func inspectorGroup<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    VStack(alignment: .leading, spacing: 0, content: content)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
  }
  private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content)
    -> some View
  {
    VStack(alignment: .leading, spacing: 8) {
      Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).padding(
        .horizontal, 12)
      inspectorGroup(content: content)
    }
  }
  private func inspectorRow<Content: View>(
    _ title: String, symbol: String, @ViewBuilder content: () -> Content
  ) -> some View {
    HStack(spacing: 10) {
      Image(systemName: symbol).font(.system(size: 17)).foregroundStyle(.secondary).frame(width: 22)
      Text(title)
      Spacer(minLength: 4)
      content()
    }.font(.body).padding(.horizontal, 14).padding(.vertical, 11)
  }
  private var reminderFeedback: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let reminderHint { Text(reminderHint).font(.caption).foregroundStyle(.secondary) }
      if showPermissionSettings {
        Button("Открыть настройки уведомлений") {
          openURL(TaskAlertScheduler.permissionSettingsURL)
        }
        .font(.caption).buttonStyle(.borderless)
      }
    }
  }
  private var reminderControls: some View {
    HStack(spacing: 10) {
      Button(reminderMode.title) {
        reminderHint = nil
        let next = reminderMode.next
        if next != .none && !hasPlan && !hasDeadline {
          reminderHint = "Сначала выбери дату дедлайна или время в календаре."
          return
        }
        if next == .alarm && (!hasPlan && !(hasDeadline && hasDeadlineTime)) {
          reminderMode = .none
          reminderHint = "Будильник требует точного времени. Сейчас напоминание выключено."
          return
        }
        if next == .alarm && !TaskAlertScheduler.supportsSystemAlarm {
          reminderMode = .none
          reminderHint = "Будильник доступен с iOS 26. Сейчас напоминание выключено."
          return
        }
        reminderMode = next
        showPermissionSettings = false
        if next != .none {
          requestingPermission = true
          Task {
            defer { requestingPermission = false }
            do { try await model.alertScheduler.prepare(next) } catch {
              reminderHint = model.friendly(error)
              showPermissionSettings = await model.alertScheduler.permissionDenied(for: next)
            }
          }
        }
        #if os(macOS)
          if next == .alarm {
            reminderHint =
              "На Mac будильник звучит при открытом приложении; при закрытом придёт уведомление."
          }
        #endif
      }.disabled(requestingPermission).accessibilityLabel(
        "Напоминание: " + reminderMode.title + ". Нажми, чтобы сменить режим")
      if reminderMode != .none {
        Menu {
          ForEach(TaskReminder.offsets, id: \.self) { minutes in
            Button(TaskReminder.offsetTitle(minutes)) { reminderMinutesBefore = minutes }
          }
        } label: {
          Text(TaskReminder.offsetTitle(reminderMinutesBefore)).lineLimit(1)
        }
      }
    }.font(.caption)
  }
  private var planningFields: some View {
    VStack(alignment: .leading, spacing: 12) {
      DatePicker("Дата", selection: $planned, displayedComponents: [.date])
      timePicker("Начало", selection: $planned)
    }
  }
  @ViewBuilder private func timePicker(_ title: String, selection: Binding<Date>) -> some View {
    #if os(iOS)
      DatePicker(title, selection: selection, displayedComponents: [.hourAndMinute])
        .datePickerStyle(.wheel).labelsHidden().frame(height: 150).clipped()
        .accessibilityLabel(title)
    #else
      DatePicker(title, selection: selection, displayedComponents: [.hourAndMinute])
    #endif
  }
  private var hasChildren: Bool {
    presentation.taskID.map { id in model.snapshot.tasks.contains { $0.parentID == id } } ?? false
  }
  private func save() async {
    var value = input
    value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
    value.plannedAt = hasPlan ? planned : nil
    value.durationMinutes = hasDuration ? duration : nil
    value.deadlineDate = hasDeadline && !hasDeadlineTime ? DateOnly.string(deadline) : nil
    value.deadlineAt = hasDeadline && hasDeadlineTime ? deadline : nil
    value.reminderMode = reminderMode
    value.reminderMinutesBefore = reminderMinutesBefore
    do {
      try TrackerRules.validate(value, id: presentation.taskID, in: model.snapshot)
      if reminderMode != .none,
        let fireDate = TaskReminder.fireDate(
          for: TaskRecord(input: value), dateOnlyMinutes: ReminderPreferences.dateOnlyMinutes),
        fireDate <= .now
      {
        let previous = presentation.taskID.flatMap { id in
          model.snapshot.tasks.first { $0.id == id }
        }
        if previous == nil || previous?.reminderMode != reminderMode
          || previous?.reminderMinutesBefore != reminderMinutesBefore
          || previous?.plannedAt != value.plannedAt || previous?.deadlineAt != value.deadlineAt
          || previous?.deadlineDate != value.deadlineDate
        {
          throw TrackerError.validation(
            "Время напоминания уже прошло. Выбери будущее время или отключи напоминание.")
        }
      }
      var permissionWarning: String?
      do { try await model.alertScheduler.prepare(reminderMode) } catch {
        permissionWarning = model.friendly(error)
      }
      try await model.mutate(.task(presentation.taskID, value))
      if let permissionWarning { model.reminderWarning = permissionWarning }
      dismissEditor()
    } catch { errorMessage = error.localizedDescription }
  }
  @ViewBuilder private func subtasks(_ id: UUID) -> some View {
    if input.parentID == nil {
      inspectorSection("Шаги проекта") {
        ForEach(model.snapshot.tasks.filter { $0.parentID == id }) { task in
          HStack {
            Button {
              model.perform(.completed(task.id, !task.completed))
            } label: {
              Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
            }.buttonStyle(.plain).disabled(!model.canEdit)
            Button {
              child = TaskPresentation(taskID: task.id, input: TaskInput(task))
            } label: {
              Text(task.title).strikethrough(task.completed).frame(
                maxWidth: .infinity, alignment: .leading)
            }.buttonStyle(.plain)
          }.padding(12)
        }
        Button {
          child = TaskPresentation(input: TaskInput(listID: input.listID, parentID: id))
        } label: {
          Label("Добавить шаг", systemImage: "plus")
        }.buttonStyle(.plain).disabled(!model.canEdit).padding(12)
      }
    }
  }
  private func comments(_ id: UUID) -> some View {
    inspectorSection("Комментарии") {
      ForEach(
        model.snapshot.comments.filter { $0.taskID == id }.sorted { $0.createdAt < $1.createdAt }
      ) { item in
        VStack(alignment: .leading, spacing: 8) {
          Text(item.text).textSelection(.enabled)
          HStack {
            Text(item.createdAt.formatted(.dateTime.day().month().hour().minute())).font(.caption)
              .foregroundStyle(.secondary)
            Spacer()
            Button("Изменить") {
              editingCommentID = item.id
              comment = item.text
            }.font(.caption).buttonStyle(.plain)
            Button("Удалить", role: .destructive) { model.perform(.deleteComment(item.id)) }.font(
              .caption
            ).buttonStyle(.plain)
          }.disabled(!model.canEdit)
        }.padding(12)
      }
      TextField("Написать комментарий…", text: $comment, axis: .vertical).lineLimit(2...5)
        .textFieldStyle(.plain).padding(12)
      HStack {
        if editingCommentID != nil {
          Button("Отменить правку") {
            editingCommentID = nil
            comment = ""
          }
        }
        Spacer()
        Button(editingCommentID == nil ? "Отправить" : "Сохранить комментарий") {
          Task {
            do {
              try await model.mutate(
                .comment(
                  editingCommentID, taskID: id,
                  text: comment.trimmingCharacters(in: .whitespacesAndNewlines)))
              comment = ""
              editingCommentID = nil
            } catch { errorMessage = error.localizedDescription }
          }
        }.disabled(
          !model.canEdit || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }.padding(12)
    }
  }
}

private struct TaskInspectorGlass: ViewModifier {
  @ViewBuilder func body(content: Content) -> some View {
    if #available(macOS 26.0, iOS 26.0, *) {
      content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 20))
    } else {
      content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
  }
}
