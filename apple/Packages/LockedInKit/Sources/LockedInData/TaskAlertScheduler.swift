import Foundation
import LockedInDomain
import Observation
import UserNotifications

#if os(iOS)
  import AlarmKit
  import SwiftUI
#elseif os(macOS)
  import AppKit
#endif

@MainActor @Observable
public final class TaskAlertScheduler {
  public private(set) var testDeliveryStatus: String?
  public private(set) var ringing: [TaskRecord] = []
  private let center = UNUserNotificationCenter.current()
  private let delegate = TaskNotificationDelegate()
  #if os(iOS)
    private let liveActivity = TaskLiveActivityManager()
  #endif
  private var generation = 0
  private var latestTasks: [TaskRecord] = []
  private var latestSpace = ""
  private var latestTags: [TagRecord] = []
  private struct Snooze: Codable {
    var signature: String
    var fireDate: Date
  }
  private var snoozes: [String: Snooze] = {
    guard let data = UserDefaults.standard.data(forKey: "taskReminderSnoozes") else { return [:] }
    return (try? JSONDecoder().decode([String: Snooze].self, from: data)) ?? [:]
  }()
  #if os(macOS)
    public var onReminder: ((TaskRecord) -> Bool)?
    private var testTimer: Timer?
    private var presentedSignatures: [UUID: String] = [:]
  #endif
  #if os(macOS)
    private var timers: [UUID: Timer] = [:]
    private var timerSignatures: [UUID: String] = [:]
    private var sound: NSSound?
  #endif
  public init() {
    center.delegate = delegate
    Task { [weak self] in
      guard let self else { return }
      let delivered = await self.center.deliveredNotifications()
      if delivered.contains(where: { $0.request.identifier == "locked-in-debug-notification" }) {
        self.testDeliveryStatus = "macOS подтвердила доставку системного тестового уведомления."
      }
    }
    delegate.stop = { [weak self] id in self?.stop(id) }
    center.setNotificationCategories([
      UNNotificationCategory(
        identifier: "locked-in-alarm",
        actions: [UNNotificationAction(identifier: "stop", title: "Остановить")],
        intentIdentifiers: [])
    ])
  }
  public static var supportsSystemAlarm: Bool {
    #if os(iOS)
      if #available(iOS 26.0, *) { return true }
      return false
    #else
      return true
    #endif
  }
  public static var permissionSettingsURL: URL {
    #if os(macOS)
      URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
    #else
      URL(string: "app-settings:")!
    #endif
  }
  public func permissionDenied(for mode: ReminderMode) async -> Bool {
    #if os(iOS)
      if mode == .alarm, #available(iOS 26.0, *) {
        return AlarmManager.shared.authorizationState == .denied
      }
    #endif
    return await center.notificationSettings().authorizationStatus == .denied
  }
  public func prepare(_ mode: ReminderMode) async throws {
    guard mode != .none else { return }
    #if os(iOS)
      if mode == .alarm {
        guard #available(iOS 26.0, *) else {
          throw TrackerError.validation(
            "Будильник доступен с iOS 26. Можно включить обычное уведомление.")
        }
        var state = AlarmManager.shared.authorizationState
        if state == .notDetermined { state = try await AlarmManager.shared.requestAuthorization() }
        guard state == .authorized else {
          throw TrackerError.validation("Разреши будильники для Locked In в настройках iPhone.")
        }
        return
      }
    #endif
    let allowed = try await center.requestAuthorization(options: [.alert, .sound, .badge])
    guard allowed else {
      throw TrackerError.validation("Разреши уведомления для Locked In в настройках устройства.")
    }
  }
  public func sendTestNotification(after delay: TimeInterval = 5) async throws {
    try await prepare(.notification)
    testDeliveryStatus = "Тест запланирован через 5 секунд."
    center.removeDeliveredNotifications(withIdentifiers: ["locked-in-debug-notification"])
    let content = UNMutableNotificationContent()
    content.title = "Locked In · тестовое уведомление"
    content.body = "Если ты видишь это сообщение, доставка уведомлений работает."
    content.sound = .default
    let request = UNNotificationRequest(
      identifier: "locked-in-debug-notification",
      content: content,
      trigger: UNTimeIntervalNotificationTrigger(
        timeInterval: delay + macFallbackDelay, repeats: false))
    try await center.add(request)
    #if os(macOS)
      testTimer?.invalidate()
      let task = TaskRecord(
        id: TaskAlertIDs.test,
        input: TaskInput(
          title: content.title, plannedAt: .now.addingTimeInterval(delay),
          reminderMode: .notification))
      testTimer = Timer(fire: .now.addingTimeInterval(delay), interval: 0, repeats: false) {
        [weak self] _ in
        Task { @MainActor in
          await self?.present(
            task, requestID: "locked-in-debug-notification", signature: UUID().uuidString)
        }
      }
      RunLoop.main.add(testTimer!, forMode: .common)
    #endif
  }
  public func snooze(_ id: UUID) async throws {
    if id == TaskAlertIDs.test {
      try await sendTestNotification(after: 300)
      return
    }
    guard let task = latestTasks.first(where: { $0.id == id }),
      let date = TaskReminder.fireDate(
        for: task, dateOnlyMinutes: ReminderPreferences.dateOnlyMinutes)
    else { throw TrackerError.notFound }
    snoozes[id.uuidString] = Snooze(
      signature: signature(task, date: date, space: latestSpace),
      fireDate: .now.addingTimeInterval(300))
    UserDefaults.standard.set(try JSONEncoder().encode(snoozes), forKey: "taskReminderSnoozes")
    stop(id)
    try await reconcile(latestTasks, tags: latestTags, space: latestSpace)
  }
  private var macFallbackDelay: TimeInterval {
    #if os(macOS)
      2
    #else
      0
    #endif
  }
  public func reconcile(_ tasks: [TaskRecord], tags: [TagRecord] = [], space: String) async throws {
    latestTasks = tasks
    latestTags = tags
    latestSpace = space
    generation += 1
    let revision = generation
    let now = Date.now
    let dated = tasks.compactMap { task -> (TaskRecord, Date)? in
      TaskReminder.fireDate(for: task, dateOnlyMinutes: ReminderPreferences.dateOnlyMinutes).map {
        let baseSignature = signature(task, date: $0, space: space)
        let snooze = snoozes[task.id.uuidString]
        return (task, snooze?.signature == baseSignature ? snooze!.fireDate : $0)
      }
    }.sorted { $0.1 < $1.1 }
    let activeIDs = Set(dated.map { $0.0.id })
    let validSnoozes = Dictionary(
      uniqueKeysWithValues: tasks.compactMap { task -> (String, Snooze)? in
        guard
          let base = TaskReminder.fireDate(
            for: task, dateOnlyMinutes: ReminderPreferences.dateOnlyMinutes),
          let snooze = snoozes[task.id.uuidString],
          snooze.signature == signature(task, date: base, space: space)
        else { return nil }
        return (task.id.uuidString, snooze)
      })
    if validSnoozes.count != snoozes.count {
      snoozes = validSnoozes
      UserDefaults.standard.set(try JSONEncoder().encode(snoozes), forKey: "taskReminderSnoozes")
    }
    let pending = await center.pendingNotificationRequests()
    guard revision == generation else { return }
    #if os(iOS)
      let notificationValues = dated.filter { $0.0.reminderMode != .alarm }
    #else
      let notificationValues = dated
    #endif
    let future = Array(notificationValues.filter { $0.1 > now }.prefix(60))
    let desiredIDs = Set(future.map { identifier($0.0.id) })
    center.removePendingNotificationRequests(
      withIdentifiers: pending.filter {
        $0.identifier.hasPrefix("locked-in-task:") && !desiredIDs.contains($0.identifier)
      }.map(\.identifier))
    let delivered = await center.deliveredNotifications()
    guard revision == generation else { return }
    center.removeDeliveredNotifications(
      withIdentifiers: delivered.filter {
        guard $0.request.identifier.hasPrefix("locked-in-task:"),
          let id = UUID(
            uuidString: String($0.request.identifier.dropFirst("locked-in-task:".count)))
        else { return false }
        return !activeIDs.contains(id)
      }.map { $0.request.identifier })
    let existing = Dictionary(uniqueKeysWithValues: pending.map { ($0.identifier, $0) })
    var warning: String?
    var notificationsAllowed = true
    if !future.isEmpty {
      let settings = await center.notificationSettings()
      guard revision == generation else { return }
      notificationsAllowed =
        settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
      if !notificationsAllowed {
        warning =
          "Напоминания сохранены, но уведомления запрещены. Разреши их в настройках устройства."
      }
    }
    for (task, date) in future where notificationsAllowed {
      guard revision == generation else { return }
      let signature = signature(task, date: date, space: space)
      if existing[identifier(task.id)]?.content.userInfo["signature"] as? String == signature {
        continue
      }
      let content = UNMutableNotificationContent()
      content.title = task.title
      content.body = task.reminderMode == .alarm ? "Будильник задачи" : "Напоминание о задаче"
      content.sound = .default
      content.categoryIdentifier =
        task.reminderMode == .alarm ? "locked-in-alarm" : "locked-in-task"
      content.userInfo = ["signature": signature, "taskID": task.id.uuidString]
      let trigger = UNTimeIntervalNotificationTrigger(
        timeInterval: max(1, date.timeIntervalSinceNow + macFallbackDelay), repeats: false)
      try await center.add(
        UNNotificationRequest(identifier: identifier(task.id), content: content, trigger: trigger))
    }
    #if os(iOS)
      if #available(iOS 26.0, *), AlarmManager.shared.authorizationState == .authorized {
        let alarms = try AlarmManager.shared.alarms
        guard revision == generation else { return }
        let values = dated.filter { $0.0.reminderMode == .alarm }
        let desired = Dictionary(
          uniqueKeysWithValues: values.map { ($0.0.id, signature($0.0, date: $0.1, space: space)) })
        var saved =
          UserDefaults.standard.dictionary(forKey: "taskAlarmSignatures") as? [String: String]
          ?? [:]
        for alarm in alarms
        where desired[alarm.id] == nil || desired[alarm.id] != saved[alarm.id.uuidString] {
          try AlarmManager.shared.cancel(id: alarm.id)
          saved.removeValue(forKey: alarm.id.uuidString)
        }
        let existingIDs = Set(alarms.map(\.id))
        for (task, date) in values where date > now {
          guard revision == generation else { return }
          let signature = desired[task.id]!
          if existingIDs.contains(task.id) && saved[task.id.uuidString] == signature { continue }
          guard AlarmManager.shared.authorizationState == .authorized else {
            throw TrackerError.validation(
              "Будильники сохранены, но не разрешены в настройках iPhone.")
          }
          let alert = AlarmPresentation.Alert(
            title: LocalizedStringResource(stringLiteral: task.title),
            stopButton: AlarmButton(
              text: "Остановить", textColor: .white, systemImageName: "stop.fill"))
          let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: TaskAlarmMetadata(taskID: task.id), tintColor: .purple)
          _ = try await AlarmManager.shared.schedule(
            id: task.id, configuration: .alarm(schedule: .fixed(date), attributes: attributes))
          saved[task.id.uuidString] = signature
        }
        UserDefaults.standard.set(saved, forKey: "taskAlarmSignatures")
      } else if dated.contains(where: { $0.0.reminderMode == .alarm && $0.1 > now }) {
        warning = "Для будильников нужны iOS 26 и разрешение в настройках iPhone."
      }
    #else
      let alarmValues = dated
      let desired = Dictionary(
        uniqueKeysWithValues: alarmValues.map {
          ($0.0.id, signature($0.0, date: $0.1, space: space))
        })
      for id in Array(timers.keys) where timerSignatures[id] != desired[id] {
        timers.removeValue(forKey: id)?.invalidate()
        timerSignatures.removeValue(forKey: id)
        stop(id)
      }
      for task in ringing where desired[task.id] == nil { stop(task.id) }
      for (task, date) in alarmValues where date > now {
        let signature = desired[task.id]!
        if timerSignatures[task.id] == signature { continue }
        let timer = Timer(fire: date, interval: 0, repeats: false) { [weak self] _ in
          Task { @MainActor in
            guard let self, self.timerSignatures[task.id] == signature else { return }
            if task.reminderMode == .alarm {
              self.center.removePendingNotificationRequests(withIdentifiers: [
                self.identifier(task.id)
              ])
              self.ring(task)
            } else {
              await self.present(task, requestID: self.identifier(task.id), signature: signature)
            }
          }
        }
        timers[task.id] = timer
        timerSignatures[task.id] = signature
        RunLoop.main.add(timer, forMode: .common)
      }
    #endif
    #if os(iOS)
      try await liveActivity.reconcile(tasks, tags: tags, space: space)
    #endif
    if let warning { throw TrackerError.validation(warning) }
    if notificationValues.filter({ $0.1 > now }).count > 60 {
      throw TrackerError.validation(
        "Запланированы ближайшие 60 уведомлений. Открывай приложение, чтобы обновлять следующие.")
    }
  }
  public func stop(_ id: UUID) {
    ringing.removeAll { $0.id == id }
    center.removeDeliveredNotifications(withIdentifiers: [identifier(id)])
    #if os(macOS)
      if ringing.isEmpty {
        sound?.stop()
        sound = nil
      }
    #endif
  }
  private func identifier(_ id: UUID) -> String { "locked-in-task:" + id.uuidString }
  private func signature(_ task: TaskRecord, date: Date, space: String) -> String {
    "v2:" + space + ":" + task.title + ":" + (task.reminderMode ?? .none).rawValue + ":"
      + String(date.timeIntervalSince1970)
  }
  #if os(macOS)
    private func present(_ task: TaskRecord, requestID: String, signature: String) async {
      if presentedSignatures[task.id] == signature { return }
      let delivered = await center.deliveredNotifications()
      if delivered.contains(where: {
        $0.request.identifier == requestID
          && $0.request.content.userInfo["signature"] as? String == signature
      }) {
        return
      }
      guard
        task.id == TaskAlertIDs.test
          || latestTasks.contains(where: { $0.id == task.id && !$0.completed })
      else { return }
      guard onReminder?(task) == true else { return }
      presentedSignatures[task.id] = signature
      if task.id == TaskAlertIDs.test {
        testDeliveryStatus = "Показана анимированная карточка Locked In. Системный дубль отменён."
      }
      center.removePendingNotificationRequests(withIdentifiers: [requestID])
      NSSound(named: "Pop")?.play()
    }
    private func ring(_ task: TaskRecord) {
      guard !ringing.contains(where: { $0.id == task.id }) else { return }
      ringing.append(task)
      if sound == nil {
        sound = NSSound(named: "Glass")
        sound?.loops = true
        sound?.play()
      }
      NSApp.activate(ignoringOtherApps: true)
    }
  #endif
}

private final class TaskNotificationDelegate: NSObject, UNUserNotificationCenterDelegate,
  @unchecked Sendable
{
  @MainActor var stop: ((UUID) -> Void)?
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    #if os(macOS)
      if notification.request.content.categoryIdentifier == "locked-in-alarm" {
        return [.banner, .list]
      }
    #endif
    return [.banner, .list, .sound]
  }
  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    if response.actionIdentifier == "stop",
      let value = response.notification.request.content.userInfo["taskID"] as? String,
      let id = UUID(uuidString: value)
    {
      await MainActor.run { stop?(id) }
    }
  }
}
#if os(iOS)
  @available(iOS 26.0, *)
  private struct TaskAlarmMetadata: AlarmMetadata { var taskID: UUID }
#endif
