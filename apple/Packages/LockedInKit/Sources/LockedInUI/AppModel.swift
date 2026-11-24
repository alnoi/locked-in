import LockedInData
import LockedInDomain
import Observation
import SwiftUI
import UserNotifications
import WidgetKit
import OSLog

@MainActor @Observable
public final class AppModel {
  public var snapshot = Snapshot()
  public var needsAuthentication = true
  var authSession: AuthSession?
  public var profileUser: UserRecord? { authSession?.user ?? (hasLoaded ? snapshot.user : nil) }
  var calendarFocus: CalendarTaskFocus?
  public private(set) var listOrderIDs: [UUID] = []
  public private(set) var taskOrderIDs: [UUID] = []
  public let alertScheduler = TaskAlertScheduler()
  let dayProgress = DayProgressState()
  private let workdaySummary = WorkdaySummaryScheduler()
  public var reminderWarning: String?
  public var settings = ConnectionSettings.saved
  public var isLoading = false
  public var isMutating = false
  @ObservationIgnored private var mutationWaiters: [CheckedContinuation<Void, Never>] = []
  public var hasLoaded = false
  public var isOffline = false
  public private(set) var unsyncedTaskIDs = Set<UUID>()
  public private(set) var visibleUnsyncedTaskIDs = Set<UUID>()
  @ObservationIgnored private var pendingFlags = PendingSyncVisibility()
  @ObservationIgnored private var pendingFlagTask: Task<Void, Never>?
  public private(set) var syncWarning: String?
  public var errorMessage: String?
  public var lastRefresh: Date?
  public var legacySource: (() throws -> [LegacyTask])?
  let actionHistory = ActionHistory()
  var undoRevision = 0
  var repository: (any TrackerRepository)?
  @ObservationIgnored private var widgetObserver: WidgetCommandObserver?
  private var started = false
  private var refreshing = false
  var mutationRevision = 0
  #if os(macOS)
    private let reminderPresenter = MacReminderPresenter()
  #endif
  public init(legacySource: (() throws -> [LegacyTask])? = nil) {
    self.legacySource = legacySource
    #if os(macOS)
      alertScheduler.onReminder = { [weak self] task in
        guard let self else { return false }
        return self.reminderPresenter.show(
          task: task, tags: self.snapshot.tags,
          complete: { [weak self] in
            guard let self else { return }
            if task.id != TaskAlertIDs.test { try await self.mutate(.completed(task.id, true)) }
          }, snooze: { [weak self] in try await self?.alertScheduler.snooze(task.id) })
      }
    #endif
  }

  public func start() async {
    guard !started else { return }
    started = true
    widgetObserver = WidgetCommandObserver { [weak self] in
      Task { @MainActor in await self?.refresh() }
    }
    if settings.mode == .server {
      do {
        guard let session = try AuthSessionStore.active(address: settings.serverAddress), session.expiresAt > .now else {
          needsAuthentication = true
          try WidgetStore.shared?.clearContext()
          WidgetCenter.shared.reloadAllTimelines()
          return
        }
        authSession = session
        settings.accountID = session.user.id
        ProfilePreferences.activate(settings.identity, inheritLegacy: settings.hasLegacyProfileData)
        ProfilePreferences.migrateLegacy(settings: settings)
        alertScheduler.reloadAccountPreferences()
      } catch { errorMessage = friendly(error); needsAuthentication = true; return }
    }
    needsAuthentication = false
    do { repository = try settings.repository() } catch {
      errorMessage = friendly(error)
      return
    }
    if settings.mode == .server, let cached = try? Data(contentsOf: cacheURL),
      let value = try? JSONCodec.decoder().decode(Snapshot.self, from: cached),
      value.user.id == authSession?.user.id
    {
      snapshot = value
      if let user = authSession?.user { snapshot.user = user }
      applyLocalListOrder()
      hasLoaded = true
      isOffline = true
    }
    if let sync = repository as? OfflineTaskRepository {
      do {
        if let restored = try await sync.restore() {
          guard settings.mode != .server || restored.user.id == authSession?.user.id else { throw AuthenticationError.sessionExpired }
          snapshot = restored
          if let user = authSession?.user { snapshot.user = user }
          applyLocalListOrder(); hasLoaded = true
        }
        receiveSyncStatus(await sync.status())
      } catch {
        errorMessage = UserFacingErrors.message(error)
        repository = nil
        hasLoaded = false
        return
      }
    }
    await refresh()
    publishWidgets(forceReload: true)
    if isOffline && hasLoaded { await refreshReminders() }
  }
  public func refresh() async {
    guard !refreshing, !isMutating, let repository else { return }
    refreshing = true
    isLoading = !hasLoaded
    let revision = mutationRevision
    defer { isLoading = false; refreshing = false }
    do {
      let value = try await repository.load()
      let status = await (repository as? OfflineTaskRepository)?.status()
      guard revision == mutationRevision, !isMutating else { return }
      guard settings.mode != .server || value.user.id == authSession?.user.id else { throw AuthenticationError.sessionExpired }
      if var session = authSession,
        session.user.username != value.user.username || session.user.avatarEmoji != value.user.avatarEmoji
          || session.user.timeZone != value.user.timeZone {
        session.user = value.user
        try AuthSessionStore.save(session, address: settings.serverAddress)
        authSession = session
      }
      snapshot = value
      applyLocalListOrder()
      hasLoaded = true
      if let status { receiveSyncStatus(status) } else { isOffline = false }
      errorMessage = nil
      lastRefresh = .now
      isLoading = false
      await importWidgetCompletions()
      cacheSnapshot()
      await refreshReminders()
    } catch {
      guard revision == mutationRevision else { return }
      if (error as? AuthenticationError) == .sessionExpired { await requireAuthentication(error); return }
      isOffline = settings.mode == .server && UserFacingErrors.isConnectionFailure(error)
      if !hasLoaded { errorMessage = friendly(error) }
      else { syncWarning = friendly(error) }
    }
  }
  private func receiveSyncStatus(_ status: TaskSyncStatus) {
    setPendingTaskIDs(status.pendingTaskIDs)
    isOffline = status.isOffline
    syncWarning = status.issue
  }
  func setPendingTaskIDs(_ ids: Set<UUID>) {
    pendingFlagTask?.cancel()
    unsyncedTaskIDs = ids
    pendingFlags.update(ids, at: .now)
    visibleUnsyncedTaskIDs = pendingFlags.visible(at: .now)
    guard !ids.isEmpty else { return }
    pendingFlagTask = Task { @MainActor [weak self] in
      guard let self else { return }
      while let delay = self.pendingFlags.nextAppearance(at: .now) {
        do { try await Task.sleep(for: .seconds(delay)) } catch { return }
        guard !Task.isCancelled else { return }
        self.visibleUnsyncedTaskIDs = self.pendingFlags.visible(at: .now)
      }
    }
  }
  public func connect(_ proposed: ConnectionSettings) async throws {
    var proposed = proposed
    guard !isMutating, !isLoading, !actionHistory.isUndoing else {
      throw TrackerError.conflict("Дождись завершения текущей операции.")
    }
    let selectedSession = proposed.mode == .server ? try AuthSessionStore.active(address: proposed.serverAddress) : nil
    if proposed.mode == .server {
      guard let selectedSession, selectedSession.expiresAt > .now else {
        await requireAuthentication(nil)
        proposed.accountID = nil
        settings = proposed; proposed.save()
        return
      }
      proposed.accountID = selectedSession.user.id
    }
    if settings.identity != proposed.identity { await clearProfilePresentation() }
    authSession = selectedSession
    if proposed.mode == .server {
      ProfilePreferences.activate(proposed.identity, inheritLegacy: proposed.hasLegacyProfileData)
      ProfilePreferences.migrateLegacy(settings: proposed)
      alertScheduler.reloadAccountPreferences()
    }
    needsAuthentication = false
    isLoading = true
    defer { isLoading = false }
    let changedSource = settings.identity != proposed.identity
    mutationRevision += 1
    settings = proposed
    proposed.save()
    errorMessage = nil
    syncWarning = nil
    if changedSource {
      try? WidgetStore.shared?.clearContext()
      WidgetCenter.shared.reloadAllTimelines()
      snapshot = Snapshot()
      hasLoaded = false
      setPendingTaskIDs([])
      applyLocalListOrder()
    }
    repository = nil
    do {
      let next = try proposed.repository()
      repository = next
      if let sync = next as? OfflineTaskRepository {
        if let restored = try await sync.restore() {
          guard proposed.mode != .server || restored.user.id == authSession?.user.id else { throw AuthenticationError.sessionExpired }
          snapshot = restored
          if let user = authSession?.user { snapshot.user = user }
          hasLoaded = true
          applyLocalListOrder()
        }
        receiveSyncStatus(await sync.status())
      }
      let loaded = try await next.load()
      guard proposed.mode != .server || loaded.user.id == authSession?.user.id else { throw AuthenticationError.sessionExpired }
      snapshot = loaded
      hasLoaded = true
      applyLocalListOrder()
      if let sync = next as? OfflineTaskRepository { receiveSyncStatus(await sync.status()) }
      else { isOffline = false; setPendingTaskIDs([]) }
      lastRefresh = .now
    } catch {
      if (error as? AuthenticationError) == .sessionExpired { await requireAuthentication(error); return }
      isOffline = proposed.mode == .server && UserFacingErrors.isConnectionFailure(error)
      syncWarning = friendly(error)
    }
    if hasLoaded {
      isLoading = false
      await importWidgetCompletions()
      cacheSnapshot()
      await refreshReminders()
    }
  }

  @discardableResult public func mutate(_ change: Change) async throws -> ChangeResult {
    guard !actionHistory.isUndoing || UndoGrouping.replaying
      || UndoGrouping.id.map({ actionHistory.activeGroups.contains($0) }) == true else {
      throw TrackerError.conflict("Дождись завершения отмены действия.")
    }
    guard let repository, hasLoaded else {
      throw TrackerError.validation("Сначала выбери доступное хранилище.")
    }
    guard !isLoading else {
      throw TrackerError.conflict("Дождись завершения загрузки.")
    }
    if isMutating {
      await withCheckedContinuation { mutationWaiters.append($0) }
    } else {
      isMutating = true
    }
    defer {
      if mutationWaiters.isEmpty {
        isMutating = false
        if settings.mode == .server { Task { await self.refresh() } }
      } else {
        mutationWaiters.removeFirst().resume()
      }
    }
    do {
      prepareActionHistory()
      let before = snapshot
      let previousTaskOrder = taskOrderIDs
      let previousListOrder = listOrderIDs
      let result = try await repository.apply(change)
      actionHistory.record(result, before: before, taskOrder: previousTaskOrder, listOrder: previousListOrder)
      mutationRevision += 1
      if let sync = repository as? OfflineTaskRepository { receiveSyncStatus(await sync.status()) }
      withAnimation(.snappy(duration: 0.25)) {
        snapshot.receive(result)
        applyLocalListOrder()
      }
      lastRefresh = .now
      cacheSnapshot()
      await refreshReminders()
      return result
    } catch {
      if let sync = repository as? OfflineTaskRepository { receiveSyncStatus(await sync.status()) }
      if (error as? AuthenticationError) == .sessionExpired { await requireAuthentication(error) }
      throw TrackerError.validation(friendly(error))
    }
  }
  public func requestReminderPermissions() async {
    do { try await alertScheduler.prepare(.notification) }
    catch { reminderWarning = friendly(error); return }
    for mode in ReminderMode.allCases
    where mode != .none
      && snapshot.tasks.contains(where: { !$0.completed && $0.reminderMode == mode })
    {
      do { try await alertScheduler.prepare(mode) } catch {
        reminderWarning = friendly(error)
        return
      }
    }
    await refreshReminders()
  }
  public func refreshReminders() async {
    #if os(macOS)
      reminderPresenter.dismissMissing(Set(snapshot.tasks.filter { !$0.completed }.map(\.id)))
    #endif
    guard hasLoaded else { return }
    let space = settings.identity + ":" + snapshot.user.id.uuidString
    dayProgress.update(tasks: snapshot.tasks, space: space)
    var warnings: [String] = []
    do {
      try await alertScheduler.reconcile(snapshot.tasks, tags: snapshot.tags, space: space)
    } catch { warnings.append(friendly(error)) }
    do {
      try await workdaySummary.reconcile(snapshot.tasks, space: space)
    } catch { warnings.append(friendly(error)) }
    reminderWarning = warnings.isEmpty ? nil : warnings.joined(separator: "\n")
  }

  public func perform(_ change: Change) {
    Task { do { try await mutate(change) } catch { errorMessage = friendly(error) } }
  }
  public func move(_ id: UUID, to listID: UUID?, includingProject: Bool = true) {
    guard let selected = snapshot.tasks.first(where: { $0.id == id }) else { return }
    let root = includingProject ? TaskProjectGrouping.root(of: selected, in: snapshot.tasks) : selected
    let group = [root] + snapshot.tasks.filter { $0.parentID == root.id }
    Task {
      do {
        try await groupedUndo {
          for task in group {
            var input = TaskInput(task)
            input.listID = listID
            if !includingProject && selected.parentID != nil { input.parentID = nil }
            try await mutate(.task(task.id, input))
          }
        }
      } catch { errorMessage = friendly(error) }
    }
  }

  public func convertToProject(_ id: UUID) {
    guard canEdit, let task = snapshot.tasks.first(where: { $0.id == id }), task.parentID == nil else { return }
    var input = TaskInput(task)
    input.isProject = true
    perform(.task(id, input))
  }

  public func dissolveProject(_ id: UUID) {
    Task {
      do { try await dissolveProjectAndWait(id) }
      catch { errorMessage = friendly(error) }
    }
  }

  func dissolveProjectAndWait(_ id: UUID) async throws {
    guard canEdit, let project = snapshot.tasks.first(where: { $0.id == id }) else { return }
    try await groupedUndo {
      let children = orderedTasks(snapshot.tasks.filter { $0.parentID == id })
      let childIDs = Set(children.map(\.id))
      var order = orderedTasks(snapshot.tasks).map(\.id).filter { !childIDs.contains($0) }
      if let index = order.firstIndex(of: id) {
        order.insert(contentsOf: children.map(\.id), at: index + 1)
      }
      saveTaskOrder(order)
      for child in children {
        guard let current = snapshot.tasks.first(where: { $0.id == child.id }),
          current.parentID == id else { continue }
        var input = TaskInput(current)
        input.parentID = nil
        input.listID = project.listID
        try await mutate(.task(child.id, input))
      }
      if let current = snapshot.tasks.first(where: { $0.id == id }) {
        var input = TaskInput(current)
        input.isProject = false
        try await mutate(.task(id, input))
      }
    }
  }

  public func projectDestinations(for task: TaskRecord) -> [TaskRecord] {
    guard task.isProject != true, !snapshot.tasks.contains(where: { $0.parentID == task.id }) else { return [] }
    let parentIDs = Set(snapshot.tasks.compactMap(\.parentID))
    return orderedTasks(snapshot.tasks.filter {
      $0.parentID == nil && $0.id != task.id && $0.id != task.parentID
        && ($0.isProject == true || parentIDs.contains($0.id))
    })
  }

  public func moveTask(_ id: UUID, intoProject projectID: UUID) {
    guard let task = snapshot.tasks.first(where: { $0.id == id }),
      let project = projectDestinations(for: task).first(where: { $0.id == projectID })
    else { return }
    var input = TaskInput(task)
    input.parentID = project.id
    input.listID = project.listID
    perform(.task(task.id, input))
  }

  public func orderedTasks(_ tasks: [TaskRecord]) -> [TaskRecord] {
    let positions = Dictionary(
      uniqueKeysWithValues: taskOrderIDs.enumerated().map { ($0.element, $0.offset) })
    return tasks.sorted {
      let left = positions[$0.id] ?? Int.max
      let right = positions[$1.id] ?? Int.max
      if left != right { return left < right }
      if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
      return $0.id.uuidString < $1.id.uuidString
    }
  }
  public func saveTaskOrder(_ visible: [UUID]) {
    let current = TaskOrderPreferences.orderedIDs(
      snapshot.tasks, space: settings.identity, userID: snapshot.user.id)
    let next = TaskOrderPreferences.merging(visible, into: current)
    if next != current {
      prepareActionHistory()
      actionHistory.record([.taskOrder(current)])
    }
    TaskOrderPreferences.save(next, space: settings.identity, userID: snapshot.user.id)
    withAnimation(.snappy(duration: 0.12, extraBounce: 0)) { taskOrderIDs = next }
  }
  public func displayListIDs(_ lists: [TaskList], includeInbox: Bool) -> [UUID] {
    let visible = Set(lists.map(\.id))
    return listOrderIDs.filter { visible.contains($0) || (includeInbox && $0 == ListOrdering.inboxID) }
  }
  public func saveListOrder(_ visible: [UUID]) {
    var ids = ListOrderPreferences.orderedIDs(
      snapshot.lists, space: settings.identity, userID: snapshot.user.id)
    let available = Set(ids)
    guard Set(visible).count == visible.count, Set(visible).isSubset(of: available) else { return }
    let selected = Set(visible)
    var replacement = visible.makeIterator()
    ids = ids.map { selected.contains($0) ? replacement.next()! : $0 }
    if ids != listOrderIDs {
      prepareActionHistory()
      actionHistory.record([.listOrder(listOrderIDs)])
    }
    ListOrderPreferences.saveIDs(ids, space: settings.identity, userID: snapshot.user.id)
    withAnimation(.snappy(duration: 0.12, extraBounce: 0)) { applyLocalListOrder() }
    cacheSnapshot()
  }
  public func reorderList(_ id: UUID, over target: UUID, visible: [UUID]) {
    guard id != target, let from = visible.firstIndex(of: id),
      let to = visible.firstIndex(of: target)
    else { return }
    var ids = ListOrderPreferences.orderedIDs(
      snapshot.lists, space: settings.identity, userID: snapshot.user.id)
    let before = from < to ? (to + 1 < visible.count ? visible[to + 1] : nil) : target
    ids.removeAll { $0 == id }
    let index = before.flatMap { ids.firstIndex(of: $0) } ?? ids.count
    ids.insert(id, at: index)
    if ids != listOrderIDs {
      prepareActionHistory()
      actionHistory.record([.listOrder(listOrderIDs)])
    }
    ListOrderPreferences.saveIDs(ids, space: settings.identity, userID: snapshot.user.id)
    withAnimation(.snappy(duration: 0.25)) { applyLocalListOrder() }
    cacheSnapshot()
  }

  func openCalendar(_ id: UUID) {
    Task {
      do {
        guard let task = snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
        let date = task.plannedAt ?? .now
        if let input = CalendarTaskNavigation.planIfNeeded(task, now: date) {
          try await mutate(.task(id, input))
        }
        calendarFocus = CalendarTaskFocus(taskID: id, date: date)
      } catch { errorMessage = friendly(error) }
    }
  }
  public func schedule(_ id: UUID, at date: Date) {
    guard let task = snapshot.tasks.first(where: { $0.id == id }) else { return }
    var input = TaskInput(task)
    input.plannedAt = date
    if input.durationMinutes == nil { input.durationMinutes = 60 }
    perform(.task(id, input))
  }
  public func importLegacy() async throws -> Int {
    guard let legacySource else { return 0 }
    let key = "legacyImported:" + settings.identity
    var imported = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
    var pending =
      UserDefaults.standard.dictionary(forKey: key + ":pending") as? [String: String] ?? [:]
    var count = 0
    for item in try legacySource() where !imported.contains(item.id.uuidString) {
      let taskID: UUID
      if let savedID = pending[item.id.uuidString].flatMap(UUID.init(uuidString:)) {
        taskID = savedID
      } else {
        let result = try await mutate(.task(nil, item.input))
        guard case .task(let task) = result else { continue }
        taskID = task.id
        pending[item.id.uuidString] = taskID.uuidString
        UserDefaults.standard.set(pending, forKey: key + ":pending")
      }
      if item.completed { try await mutate(.completed(taskID, true)) }
      imported.insert(item.id.uuidString)
      UserDefaults.standard.set(Array(imported), forKey: key)
      pending.removeValue(forKey: item.id.uuidString)
      UserDefaults.standard.set(pending, forKey: key + ":pending")
      count += 1
    }
    return count
  }
  public var canEdit: Bool { hasLoaded && !isLoading }
  public var canEditCollections: Bool { canEdit && (isOffline || visibleUnsyncedTaskIDs.isEmpty) }
  public func friendly(_ error: Error) -> String { UserFacingErrors.message(error) }

  func clearProfilePresentation() async {
    let space = settings.identity + ":" + snapshot.user.id.uuidString
    calendarFocus = nil
    repository = nil
    mutationRevision += 1
    setPendingTaskIDs([])
    hasLoaded = false
    isLoading = false
    isOffline = false
    syncWarning = nil
    reminderWarning = nil
    snapshot = Snapshot()
    listOrderIDs = []; taskOrderIDs = []
    actionHistory.prepare(source: "signed-out")
    dayProgress.setOverdueVisible(false)
    dayProgress.update(tasks: [], space: "signed-out")
    try? WidgetStore.shared?.clearContext()
    WidgetCenter.shared.reloadAllTimelines()
    for task in alertScheduler.ringing { alertScheduler.stop(task.id) }
    #if os(macOS)
    reminderPresenter.dismissMissing([])
    #endif
    do { try await alertScheduler.reconcile([], space: space) }
    catch { reminderWarning = friendly(error) }
    do { try await workdaySummary.reconcile([], space: space) }
    catch { reminderWarning = friendly(error) }
  }
  private func applyLocalListOrder() {
    listOrderIDs = ListOrderPreferences.orderedIDs(
      snapshot.lists, space: settings.identity, userID: snapshot.user.id)
    taskOrderIDs = TaskOrderPreferences.orderedIDs(
      snapshot.tasks, space: settings.identity, userID: snapshot.user.id)

    var orderedSnapshot = snapshot
    ListOrderPreferences.apply(to: &orderedSnapshot, space: settings.identity)
    snapshot = orderedSnapshot
  }
  private var cacheURL: URL {
    let key = Data(settings.identity.utf8).base64EncodedString().replacingOccurrences(
      of: "/", with: "_")
    return ConnectionSettings.supportDirectory.appendingPathComponent("cache_" + key + ".json")
  }
  public func publishWidgets(forceReload: Bool = false) {
    guard hasLoaded, let store = WidgetStore.shared else { return }
    do {
      let changed = try store.publish(WidgetSnapshot(snapshot: snapshot, settings: settings,
        pendingTaskIDs: unsyncedTaskIDs, theme: UserDefaults.standard.string(forKey: "trackit.appearance") ?? "system"))
      if changed {
        Logger(subsystem: "com.alan.planner", category: "widgets").info("Published widget snapshot: \(self.snapshot.tasks.count) tasks")
      }
      if changed || forceReload {
        WidgetCenter.shared.reloadTimelines(ofKind: "TrackIt.Today")
        WidgetCenter.shared.reloadTimelines(ofKind: "TrackIt.Calendar")
      }
    } catch {
      Logger(subsystem: "com.alan.planner", category: "widgets").error("Widget export failed: \(error.localizedDescription, privacy: .public)")
      // Widget export must never prevent a successful task save.
    }
  }
  private func importWidgetCompletions() async {
    guard let store = WidgetStore.shared else { return }
    let key = settings.identity + ":" + snapshot.user.id.uuidString
    do {
      for command in try store.commands(sourceKey: key) {
        guard let task = snapshot.tasks.first(where: { $0.id == command.taskID }) else {
          try store.remove(command); continue
        }
        let superseded = command.acknowledgedTask.map { task.updatedAt > $0.updatedAt } ?? false
        if !task.completed && !superseded {
          _ = try await UndoGrouping.$replaying.withValue(true) { try await mutate(.completed(task.id, true)) }
        }
        try store.remove(command)
      }
    } catch { syncWarning = "Не удалось применить изменение из виджета: " + friendly(error) }
  }
  func cacheSnapshot() {
    if hasLoaded { dayProgress.update(tasks: snapshot.tasks, space: settings.identity + ":" + snapshot.user.id.uuidString) }
    publishWidgets()
    guard settings.mode == .server else { return }
    do {
      try FileManager.default.createDirectory(
        at: ConnectionSettings.supportDirectory, withIntermediateDirectories: true)
      try JSONCodec.encoder().encode(snapshot).write(to: cacheURL, options: .atomic)
    } catch {
      errorMessage =
        UserFacingErrors.message(error)
    }
  }
}
