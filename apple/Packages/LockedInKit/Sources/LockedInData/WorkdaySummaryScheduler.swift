import Foundation
import LockedInDomain
import UserNotifications

@available(iOSApplicationExtension, unavailable)
@MainActor
public final class WorkdaySummaryScheduler {
  private struct Input {
    var tasks: [TaskRecord]
    var space: String
    var endMinutes: Int
    var now: Date
  }
  private let center = UNUserNotificationCenter.current()
  private let prefix = "trackit-day-summary:"
  private var pending: Input?
  private var reconciling = false
  public init() {}
  public func reconcile(_ tasks: [TaskRecord], space: String, now: Date = .now) async throws {
    pending = Input(tasks: tasks, space: space, endMinutes: WorkdayPreferences.endMinutes, now: now)
    guard !reconciling else { return }
    reconciling = true
    defer { reconciling = false }
    while let input = pending {
      pending = nil
      try await schedule(input)
    }
  }
  private func schedule(_ input: Input) async throws {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: input.now)
    let grouped = Dictionary(grouping: input.tasks.filter { !$0.completed && ($0.plannedAt ?? .distantPast) >= today }) {
      calendar.startOfDay(for: $0.plannedAt!)
    }
    let days = Array(grouped.keys.sorted().prefix(3))
    let requests = await center.pendingNotificationRequests().filter { $0.identifier.hasPrefix(prefix) }
    let wanted = Set(days.map { prefix + WidgetAgenda.dayKey($0) })
    center.removePendingNotificationRequests(withIdentifiers: requests.filter { !wanted.contains($0.identifier) }.map(\.identifier))
    guard !days.isEmpty else { return }
    let settings = await center.notificationSettings()
    if settings.authorizationStatus == .notDetermined {
      guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
        throw TrackerError.validation("Разреши уведомления TrackIt для итогов рабочего дня.")
      }
    } else if settings.authorizationStatus != .authorized && settings.authorizationStatus != .provisional {
      throw TrackerError.validation("Разреши уведомления TrackIt для итогов рабочего дня.")
    }
    let key = "trackit.daySummary." + Data(input.space.utf8).base64EncodedString()
    var scheduled = UserDefaults.standard.dictionary(forKey: key) as? [String: Double] ?? [:]
    let oldest = WidgetAgenda.dayKey(calendar.date(byAdding: .day, value: -7, to: today)!)
    scheduled = scheduled.filter { $0.key >= oldest }
    for day in days {
      let dayKey = WidgetAgenda.dayKey(day)
      let id = prefix + dayKey
      let date = calendar.date(bySettingHour: input.endMinutes / 60, minute: input.endMinutes % 60, second: 0, of: day)!
      if date <= input.now, let previous = scheduled[dayKey], previous <= input.now.timeIntervalSince1970 { continue }
      let count = grouped[day]?.count ?? 0
      let signature = input.space + ":" + String(date.timeIntervalSince1970) + ":" + String(count)
      if requests.contains(where: { $0.identifier == id && $0.content.userInfo["signature"] as? String == signature }) { continue }
      let content = UNMutableNotificationContent()
      content.title = "Рабочий день заканчивается"
      content.body = "На сегодня осталось невыполненных задач: \(count)."
      content.sound = .default
      content.userInfo = ["signature": signature]
      let trigger: UNNotificationTrigger
      let fireDate: Date
      if date <= input.now {
        trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        fireDate = input.now.addingTimeInterval(1)
      } else {
        trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date), repeats: false)
        fireDate = date
      }
      try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
      scheduled[dayKey] = fireDate.timeIntervalSince1970
      UserDefaults.standard.set(scheduled, forKey: key)
    }
  }
}
