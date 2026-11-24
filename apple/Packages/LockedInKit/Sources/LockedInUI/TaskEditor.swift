import LockedInData
import LockedInDomain
import SwiftUI

struct TaskEditor: View {
  @Bindable var model: AppModel
  let presentation: TaskPresentation
  private let close: (() -> Void)?
  private let saveOnOutside: Bool
  @Environment(\.dismiss) private var presentationDismiss
  @Environment(\.openURL) private var openURL
  @State private var reminderMode: ReminderMode
  @State private var reminderMinutesBefore: Int
  @State private var reminderHint: String?
  @State private var requestingPermission = false
  @State private var showPermissionSettings = false
  @State private var links: TaskLinks
  @State private var urlDraft = ""
  @State private var urlFocusRequest = 0
  @State private var noteSaving = false
  @State private var savedInput: TaskInput
  @State private var input: TaskInput
  @State private var hasDeadline: Bool
  @State private var hasDeadlineTime: Bool
  @State private var showDeadlineTime = false
  @State private var deadline: Date
  @State private var hasPlan: Bool
  @State private var planned: Date
  @State private var hasDuration: Bool
  @State private var duration: Int
  @State private var errorMessage: String?
  @State private var confirmDelete = false
  @State private var saving = false
  @State private var comment = ""
  @State private var editingCommentID: UUID?
  @State private var child: TaskPresentation?
  @FocusState private var titleFocused: Bool
  init(model: AppModel, presentation: TaskPresentation, saveOnOutside: Bool = false, close: (() -> Void)? = nil) {
    self.model = model
    self.presentation = presentation
    self.close = close
    self.saveOnOutside = saveOnOutside
    _reminderMode = State(initialValue: presentation.input.reminderMode ?? .none)
    _reminderMinutesBefore = State(initialValue: presentation.input.reminderMinutesBefore ?? 0)
    _input = State(initialValue: presentation.input)
    _savedInput = State(initialValue: presentation.input)
    _links = State(initialValue: TaskLinks(stored: presentation.input.description))
    _hasDeadline = State(
      initialValue: presentation.input.deadlineAt != nil || presentation.input.deadlineDate != nil)
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
      ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if let id = presentation.taskID, model.visibleUnsyncedTaskIDs.contains(id) {
            Label("Сохранено на устройстве · ожидает синхронизации", systemImage: "flag.fill")
              .font(.caption).foregroundStyle(.red).padding(.horizontal, 12)
          }
          inspectorGroup {
            TextField("Название задачи", text: $input.title, axis: .vertical)
              .font(.system(size: 23, weight: .semibold, design: .rounded)).lineLimit(1...4)
              .textFieldStyle(.plain).focused($titleFocused).accessibilityIdentifier("task-title")
              .submitLabel(.done).onSubmit { Task { await save() } }
              .padding(14)
          }
          if let taskID = presentation.taskID { comments(taskID) }
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
                  .onSubmit { Task { await save() } }
                  .multilineTextAlignment(.trailing).frame(width: 45)
                Text("мин").foregroundStyle(.secondary)
              }
              Toggle("Длительность", isOn: $hasDuration).labelsHidden().toggleStyle(.switch)
                .controlSize(.small)
            }
          }
          inspectorSection("Дедлайн") {
            inspectorRow("Дедлайн", symbol: "calendar") {
              Toggle("Дедлайн", isOn: $hasDeadline).labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            if hasDeadline { deadlineFields.padding(.horizontal, 14).padding(.bottom, 10) }
            groupDivider
            inspectorRow("Напоминание", symbol: reminderMode.symbol) { reminderControls }
            reminderFeedback.padding(.horizontal, 14)
          }
          if let taskID = presentation.taskID { subtasks(taskID) }
          inspectorSection("Ссылки") {
            TaskLinksField(links: $links, draft: $urlDraft, focusRequest: urlFocusRequest, onSave: persistLinks)
          }.id("task-links")
          if presentation.taskID != nil {
            Button("Удалить задачу", role: .destructive) { confirmDelete = true }
              .buttonStyle(.plain).font(.subheadline).padding(.horizontal, 12)
          }
          EditorFooter(message: errorMessage)
        }.padding(12)
      }.onChange(of: urlFocusRequest) { _, _ in
        withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo("task-links", anchor: .center) }
      }
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
            !model.canEdit || requestingPermission || saving
              || input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          )
          .keyboardShortcut(.return, modifiers: .command)
      }.padding(14)
    }
    .modifier(TaskInspectorGlass())
    .onChange(of: model.undoRevision) { _, _ in reloadAfterUndo() }
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
    .background {
      AppShortcutHandler(priority: 100, enabled: child == nil && !confirmDelete && !requestingPermission,
        focusOnAppear: !isCreating, submitDatePickerOnReturn: true, handle: handleShortcut).allowsHitTesting(false)
    }
    .background {
      QuickTaskOutsideClick(enabled: (isCreating || saveOnOutside) && !saving && !requestingPermission && !confirmDelete && child == nil,
        includeSheetParent: true, outside: finishOutside).allowsHitTesting(false)
    }
  }
  private func finishOutside() {
    guard !saving, !requestingPermission, !confirmDelete, child == nil else { return }
    if isCreating { finishCreation() }
    else if saveOnOutside { Task { await save(onlyIfChanged: true) } }
  }
  private func finishCreation() {
    guard isCreating, !saving, !requestingPermission, child == nil else { return }
    if input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      dismissEditor()
    } else {
      Task { await save() }
    }
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
  private var deadlineFields: some View {
    HStack(spacing: 8) {
      DatePicker("Дата дедлайна", selection: $deadline, displayedComponents: [.date])
        .datePickerStyle(.compact).labelsHidden().fixedSize()
      Spacer(minLength: 0)
      #if os(iOS)
      Button {
        hasDeadlineTime = true
        showDeadlineTime = true
      } label: {
        Text(hasDeadlineTime ? deadline.formatted(date: .omitted, time: .shortened) : "Добавить время")
          .font(.caption)
      }.popover(isPresented: $showDeadlineTime) {
        VStack(spacing: 12) {
          timePicker("Время дедлайна", selection: $deadline)
          HStack {
            Button("Без времени") { hasDeadlineTime = false; showDeadlineTime = false }
            Spacer()
            Button("Готово") { showDeadlineTime = false }
          }
        }.padding().frame(width: 280).presentationCompactAdaptation(.popover)
      }
      #else
      if hasDeadlineTime {
        DatePicker("Время дедлайна", selection: $deadline, displayedComponents: [.hourAndMinute])
          .datePickerStyle(.compact).labelsHidden().fixedSize()
        Button { hasDeadlineTime = false } label: {
          Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
        }.buttonStyle(.plain).help("Убрать время дедлайна").accessibilityLabel("Убрать время дедлайна")
      } else {
        Button("Добавить время") { hasDeadlineTime = true }.buttonStyle(.plain)
          .font(.caption).foregroundStyle(Color.accent)
      }
      #endif
    }
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
  private func persistLinks(_ updated: TaskLinks) async throws {
    guard let id = presentation.taskID else { return }
    guard let task = model.snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
    var value = TaskInput(task)
    value.description = try updated.stored()
    try await model.mutate(.task(id, value))
    input.description = value.description
    savedInput.description = value.description
  }
  private func taskValue() throws -> TaskInput {
    var value = input
    value.title = value.title.trimmingCharacters(in: .whitespacesAndNewlines)
    value.plannedAt = hasPlan ? planned : nil
    value.durationMinutes = hasDuration ? duration : nil
    value.deadlineDate = hasDeadline && !hasDeadlineTime ? DateOnly.string(deadline) : nil
    value.deadlineAt = hasDeadline && hasDeadlineTime ? deadline : nil
    value.reminderMode = reminderMode
    value.reminderMinutesBefore = reminderMinutesBefore
    value.description = try links.stored(adding: urlDraft)
    return value
  }
  private func persistTask(onlyIfChanged: Bool) async throws {
    let value = try taskValue()
    let changed = try TaskEditorChanges.hasChanges(value, from: savedInput)
    if !onlyIfChanged || isCreating || changed {
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
      savedInput = value
      if let permissionWarning { model.reminderWarning = permissionWarning }
    }
    if onlyIfChanged, let id = presentation.taskID,
      !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      try await model.mutate(.comment(editingCommentID, taskID: id,
        text: comment.trimmingCharacters(in: .whitespacesAndNewlines)))
      comment = ""
      editingCommentID = nil
    }
  }
  private func save(onlyIfChanged: Bool = false) async {
    guard !saving else { return }
    saving = true
    defer { saving = false }
    do {
      try await persistTask(onlyIfChanged: onlyIfChanged)
      dismissEditor()
    } catch { errorMessage = error.localizedDescription }
  }
  private func reloadAfterUndo() {
    guard let id = presentation.taskID else { return }
    guard let task = model.snapshot.tasks.first(where: { $0.id == id }) else {
      dismissEditor()
      return
    }
    let value = TaskInput(task)
    guard value != savedInput else { return }
    input = value
    savedInput = value
    links = TaskLinks(stored: value.description)
    hasDeadline = value.deadlineAt != nil || value.deadlineDate != nil
    hasDeadlineTime = value.deadlineAt != nil
    deadline = value.deadlineAt ?? value.deadlineDate.flatMap(DateOnly.parse) ?? .now
    hasPlan = value.plannedAt != nil
    planned = value.plannedAt ?? .now
    hasDuration = value.durationMinutes != nil
    duration = value.durationMinutes ?? 60
    reminderMode = value.reminderMode ?? .none
    reminderMinutesBefore = value.reminderMinutesBefore ?? 0
  }
  private func handleShortcut(_ shortcut: AppShortcut) -> Bool {
    switch shortcut {
    case .submit:
      guard !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return true }
      Task { await save() }
    case .close:
      if !saving && !noteSaving { dismissEditor() }
    case .links:
      urlFocusRequest += 1
    case .sidebar:
      NotificationCenter.default.post(name: .appShortcut, object: shortcut)
    case .search, .newInboxTask, .previousSection:
      Task { await forwardShortcut(shortcut) }
    case .unplan:
      if presentation.taskID == nil {
        hasPlan = false
        input.plannedAt = nil
      } else { Task { await taskAction(shortcut) } }
    case .complete, .delete, .project, .togglePlan:
      if presentation.taskID != nil { Task { await taskAction(shortcut) } }
    default: return false
    }
    return true
  }
  private func forwardShortcut(_ shortcut: AppShortcut) async {
    guard !saving else { return }
    saving = true
    defer { saving = false }
    do {
      if !isCreating || !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        try await persistTask(onlyIfChanged: true)
      }
      dismissEditor()
      DispatchQueue.main.async { NotificationCenter.default.post(name: .appShortcut, object: shortcut) }
    } catch { errorMessage = error.localizedDescription }
  }
  private func taskAction(_ action: AppShortcut) async {
    guard !saving, model.canEdit, let id = presentation.taskID else { return }
    saving = true
    defer { saving = false }
    do {
      switch action {
      case .complete:
        try await model.groupedUndo {
          try await persistTask(onlyIfChanged: true)
          try await model.mutate(.completed(id, true))
        }
        dismissEditor()
      case .delete:
        try await model.deleteProjectAndWait(id)
        dismissEditor()
      case .unplan, .togglePlan:
        guard let task = model.snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
        if action == .unplan || hasPlan {
          if task.plannedAt != nil {
            try await model.mutate(.task(id, CalendarTaskNavigation.unschedule(task)))
          }
          hasPlan = false
          input.plannedAt = nil
          savedInput.plannedAt = nil
          if action == .togglePlan && saveOnOutside { dismissEditor() }
        } else {
          let date = Date.now
          try await model.groupedUndo {
            try await persistTask(onlyIfChanged: true)
            guard let current = model.snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
            if let value = CalendarTaskNavigation.planIfNeeded(current, now: date) {
              try await model.mutate(.task(id, value))
            }
          }
          dismissEditor()
          model.calendarFocus = CalendarTaskFocus(taskID: id, date: date)
        }
      case .project:
        guard input.parentID == nil else { return }
        let isProject = input.isProject == true || model.snapshot.tasks.contains { $0.parentID == id }
        if isProject {
          try await model.groupedUndo {
            try await persistTask(onlyIfChanged: true)
            try await model.dissolveProjectAndWait(id)
          }
          input.isProject = false
          savedInput.isProject = false
        } else {
          input.isProject = true
          try await persistTask(onlyIfChanged: true)
        }
      default: break
      }
    } catch { errorMessage = error.localizedDescription }
  }
  private func saveNote(_ id: UUID) async {
    let text = comment.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !noteSaving, !text.isEmpty, model.canEditCollections else { return }
    noteSaving = true
    defer { noteSaving = false }
    do {
      try await model.mutate(.comment(editingCommentID, taskID: id, text: text))
      comment = ""
      editingCommentID = nil
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
    inspectorSection("Заметки") {
      if let note = links.legacyNote {
        VStack(alignment: .leading, spacing: 6) {
          Text("Сохранённая заметка").font(.caption).foregroundStyle(.secondary)
          Text(WebLinks.attributed(note)).tint(Color.accent).textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
        }.padding(12)
      }
      ForEach(
        model.snapshot.comments.filter { $0.taskID == id }.sorted { $0.createdAt < $1.createdAt }
      ) { item in
        VStack(alignment: .leading, spacing: 8) {
          Text(WebLinks.attributed(item.text)).tint(Color.accent)
            .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
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
          }.disabled(!model.canEditCollections)
        }.padding(12)
      }
      TextField("Написать заметку…", text: $comment, axis: .vertical).lineLimit(1...5)
        .textFieldStyle(.plain).fixedSize(horizontal: false, vertical: true)
        .submitLabel(.done).onSubmit { Task { await saveNote(id) } }.submitScope()
        .padding(.horizontal, 12).padding(.vertical, 8)
      if editingCommentID != nil || !comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      HStack {
        if editingCommentID != nil {
          Button("Отменить правку") {
            editingCommentID = nil
            comment = ""
          }
        }
        Spacer()
        Button(editingCommentID == nil ? "Добавить заметку" : "Сохранить заметку") {
          Task { await saveNote(id) }
        }.disabled(
          !model.canEditCollections || noteSaving || comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }.font(.caption).controlSize(.small).padding(.horizontal, 12).padding(.bottom, 8)
      }
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
