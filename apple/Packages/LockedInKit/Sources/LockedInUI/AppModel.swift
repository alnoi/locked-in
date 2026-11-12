import LockedInData
import LockedInDomain
import Observation
import SwiftUI
import UserNotifications

@MainActor @Observable
public final class AppModel {
  public var snapshot = Snapshot()
  public private(set) var listOrderIDs: [UUID] = []
  public private(set) var taskOrderIDs: [UUID] = []
  public let alertScheduler = TaskAlertScheduler()
  public var reminderWarning: String?
  public var settings = ConnectionSettings.saved
  public var isLoading = false
  public var isMutating = false
  public var hasLoaded = false
  public var isOffline = false
  public var errorMessage: String?
  public var lastRefresh: Date?
  public var legacySource: (() throws -> [LegacyTask])?
  private var repository: (any TrackerRepository)?
  private var started = false
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
    do { repository = try settings.repository() } catch {
      errorMessage = error.localizedDescription
      return
    }
    if settings.mode == .server, let cached = try? Data(contentsOf: cacheURL),
      let value = try? JSONCodec.decoder().decode(Snapshot.self, from: cached)
    {
      snapshot = value
      applyLocalListOrder()
      hasLoaded = true
      isOffline = true
    }
    await refresh()
    if isOffline && hasLoaded { await refreshReminders() }
  }
  public func refresh() async {
    guard !isLoading, !isMutating, let repository else { return }
    isLoading = true
    defer { isLoading = false }
    do {
      let value = try await repository.load()
      snapshot = value
      applyLocalListOrder()
      hasLoaded = true
      isOffline = false
      errorMessage = nil
      lastRefresh = .now
      cacheSnapshot()
      await refreshReminders()
    } catch {
      isOffline = settings.mode == .server
      if !hasLoaded { errorMessage = friendly(error) }
    }
  }
  public func connect(_ proposed: ConnectionSettings) async throws {
    guard !isMutating, !isLoading else {
      throw TrackerError.conflict("Дождись завершения текущей операции.")
    }
    isLoading = true
    defer { isLoading = false }
    let next = try proposed.repository()
    let value = try await next.load()
    repository = next
    settings = proposed
    proposed.save()
    snapshot = value
    applyLocalListOrder()
    hasLoaded = true
    isOffline = false
    errorMessage = nil
    lastRefresh = .now
    cacheSnapshot()
    await refreshReminders()
  }
  @discardableResult public func mutate(_ change: Change) async throws -> ChangeResult {
    guard let repository, hasLoaded else {
      throw TrackerError.validation("Сначала выбери доступное хранилище.")
    }
    guard !isOffline else {
      throw TrackerError.validation(
        "Нет связи с сервером. Обнови подключение перед изменением данных.")
    }
    guard !isMutating, !isLoading else {
      throw TrackerError.conflict("Дождись завершения текущей операции.")
    }
    isMutating = true
    defer { isMutating = false }
    do {
      let result = try await repository.apply(change)
      withAnimation(.snappy(duration: 0.25)) {
        snapshot.receive(result)
        applyLocalListOrder()
      }
      lastRefresh = .now
      cacheSnapshot()
      await refreshReminders()
      return result
    } catch { throw TrackerError.validation(friendly(error)) }
  }
  public func requestReminderPermissions() async {
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
    do {
      try await alertScheduler.reconcile(
        snapshot.tasks, tags: snapshot.tags,
        space: settings.identity + ":" + snapshot.user.id.uuidString)
      reminderWarning = nil
    } catch { reminderWarning = error.localizedDescription }
  }
  public func perform(_ change: Change) {
    Task { do { try await mutate(change) } catch { errorMessage = error.localizedDescription } }
  }
  public func move(_ id: UUID, to listID: UUID?) {
    guard let task = snapshot.tasks.first(where: { $0.id == id }) else { return }
    var input = TaskInput(task)
    input.listID = listID
    perform(.task(id, input))
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
    TaskOrderPreferences.save(next, space: settings.identity, userID: snapshot.user.id)
    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { taskOrderIDs = next }
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
    ListOrderPreferences.saveIDs(ids, space: settings.identity, userID: snapshot.user.id)
    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { applyLocalListOrder() }
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
    ListOrderPreferences.saveIDs(ids, space: settings.identity, userID: snapshot.user.id)
    withAnimation(.snappy(duration: 0.25)) { applyLocalListOrder() }
    cacheSnapshot()
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
  public var canEdit: Bool { hasLoaded && !isOffline && !isMutating && !isLoading }
  public func friendly(_ error: Error) -> String {
    if (error as NSError).domain == UNErrorDomain {
      return
        "Задача сохранится, но уведомления пока недоступны. Разреши их для Locked In в системных настройках уведомлений."
    }
    if let error = error as? URLError {
      switch error.code {
      case .cannotConnectToHost, .cannotFindHost, .notConnectedToInternet, .timedOut,
        .networkConnectionLost:
        return
          "Не удалось связаться с сервером. Проверь, что бэкенд запущен, или выбери хранение на устройстве."
      default: return "Ошибка подключения. Проверь адрес сервера и попробуй снова."
      }
    }
    return error.localizedDescription
  }
  private func applyLocalListOrder() {
    listOrderIDs = ListOrderPreferences.orderedIDs(
      snapshot.lists, space: settings.identity, userID: snapshot.user.id)
    taskOrderIDs = TaskOrderPreferences.orderedIDs(
      snapshot.tasks, space: settings.identity, userID: snapshot.user.id)

    ListOrderPreferences.apply(to: &snapshot, space: settings.identity)
  }
  private var cacheURL: URL {
    let key = Data(settings.identity.utf8).base64EncodedString().replacingOccurrences(
      of: "/", with: "_")
    return ConnectionSettings.supportDirectory.appendingPathComponent("cache_" + key + ".json")
  }
  private func cacheSnapshot() {
    guard settings.mode == .server else { return }
    do {
      try FileManager.default.createDirectory(
        at: ConnectionSettings.supportDirectory, withIntermediateDirectories: true)
      try JSONCodec.encoder().encode(snapshot).write(to: cacheURL, options: .atomic)
    } catch {
      errorMessage =
        "Данные на сервере сохранены, но не удалось обновить локальную копию: \(error.localizedDescription)"
    }
  }
}
