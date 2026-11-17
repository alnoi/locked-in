import AppIntents
import LockedInData
import LockedInDomain
import OSLog
import SwiftUI
import WidgetKit

public enum PlannerWidgetKind {
  public static let today = "TrackIt.Today"
  public static let calendar = "TrackIt.Calendar"
}

public struct CompleteWidgetTaskIntent: AppIntent {
  public static var title: LocalizedStringResource = "Завершить задачу TrackIt"
  public static var description = IntentDescription("Отметить задачу выполненной, сохранив изменения на устройстве.")
  @Parameter(title: "Задача") public var taskID: String
  @Parameter(title: "Пространство") public var sourceKey: String
  public init() {}
  public init(taskID: UUID, sourceKey: String) { self.taskID = taskID.uuidString; self.sourceKey = sourceKey }
  public func perform() async throws -> some IntentResult {
    guard let id = UUID(uuidString: taskID), let store = WidgetStore.shared else {
      throw TrackerError.validation("Открой TrackIt, чтобы подключить виджеты.")
    }
    try await WidgetService.complete(taskID: id, sourceKey: sourceKey, store: store)
    WidgetCenter.shared.reloadAllTimelines()
    return .result()
  }
}

public struct PlannerWidgetEntry: TimelineEntry {
  public var date: Date
  public var snapshot: WidgetSnapshot?
  public init(date: Date, snapshot: WidgetSnapshot?) { self.date = date; self.snapshot = snapshot }
  public var tasks: [TaskRecord] { snapshot?.tasks ?? [] }
  public var today: [TaskRecord] { WidgetAgenda.today(tasks, now: date) }
  public var completedToday: Int {
    WidgetAgenda.today(tasks, now: date, includeCompleted: true).filter(\.completed).count
  }
  public static var sample: PlannerWidgetEntry {
    let now = Date.now
    let calendar = Calendar.current
    let day = calendar.startOfDay(for: now)
    let work = TagRecord(name: "работа", color: "#6558E8")
    let study = TagRecord(name: "учёба", color: "#E5A044")
    let tasks = [
      TaskRecord(input: TaskInput(title: "Собрать мысли в план", plannedAt: day.addingTimeInterval(10 * 3600), durationMinutes: 60, tagIDs: [work.id])),
      TaskRecord(input: TaskInput(title: "Разобраться с новой темой", plannedAt: day.addingTimeInterval(14 * 3600), durationMinutes: 90, tagIDs: [study.id])),
      TaskRecord(input: TaskInput(title: "Время для себя", deadlineDate: WidgetAgenda.dayKey(now))),
      TaskRecord(input: TaskInput(title: "Зарядка", plannedAt: day.addingTimeInterval(8 * 3600), durationMinutes: 20), completed: true),
    ]
    return PlannerWidgetEntry(date: now,
      snapshot: WidgetSnapshot(snapshot: Snapshot(tasks: tasks, tags: [work, study]), settings: ConnectionSettings(mode: .local)))
  }
}

struct PlannerTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> PlannerWidgetEntry { .sample }
  func getSnapshot(in context: Context, completion: @escaping (PlannerWidgetEntry) -> Void) {
    completion(context.isPreview ? .sample : PlannerWidgetEntry(date: .now, snapshot: try? WidgetStore.shared?.displaySnapshot()))
  }
  func getTimeline(in context: Context, completion: @escaping (Timeline<PlannerWidgetEntry>) -> Void) {
    Task {
      let now = Date.now
      let snapshot: WidgetSnapshot?
      let logger = Logger(subsystem: "com.alan.planner", category: "widgets")
      if let store = WidgetStore.shared {
        do {
          // App-triggered reloads must render its latest edits without waiting
          // for the network or replacing them with an in-flight server response.
          if let local = try store.context(), now.timeIntervalSince(local.updatedAt) < 60 {
            snapshot = try store.displaySnapshot()
          } else {
            snapshot = try await WidgetService.refresh(store: store)
          }
          logger.info("Widget timeline loaded: \(snapshot?.tasks.count ?? 0) tasks")
        } catch {
          logger.error("Widget timeline failed: \(error.localizedDescription, privacy: .public)")
          snapshot = try? store.displaySnapshot()
        }
      } else {
        logger.error("Widget shared container unavailable")
        snapshot = nil
      }
      let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
      let changes = (snapshot?.tasks ?? []).compactMap(\.deadlineAt).filter { $0 > now && $0 < tomorrow }
      let dates = Array(Set([now, tomorrow] + changes)).sorted().prefix(24)
      completion(Timeline(entries: dates.map { PlannerWidgetEntry(date: $0, snapshot: snapshot) },
        policy: .after(now.addingTimeInterval(15 * 60))))
    }
  }
}

public struct TodayWidget: Widget {
  public init() {}
  public var body: some WidgetConfiguration {
    StaticConfiguration(kind: PlannerWidgetKind.today, provider: PlannerTimelineProvider()) { entry in
      TodayWidgetView(entry: entry).modifier(WidgetTheme(theme: entry.snapshot?.theme))
        .containerBackground(for: .widget) { WidgetBackdrop().modifier(WidgetTheme(theme: entry.snapshot?.theme)) }
    }.configurationDisplayName("Сегодня")
      .description("Задачи на сегодня, ближайшее дело и завершение одним нажатием.")
      .supportedFamilies([.systemMedium, .systemLarge])
  }
}

public struct CalendarWidget: Widget {
  public init() {}
  public var body: some WidgetConfiguration {
    StaticConfiguration(kind: PlannerWidgetKind.calendar, provider: PlannerTimelineProvider()) { entry in
      CalendarWidgetView(entry: entry).modifier(WidgetTheme(theme: entry.snapshot?.theme))
        .containerBackground(for: .widget) { WidgetBackdrop().modifier(WidgetTheme(theme: entry.snapshot?.theme)) }
    }.configurationDisplayName("Календарь")
      .description("Месяц и расписание дня. Открой нужный день или задачу одним нажатием.")
      .supportedFamilies([.systemMedium, .systemLarge])
  }
}

struct WidgetTheme: ViewModifier {
  var theme: String?
  @Environment(\.colorScheme) private var system
  func body(content: Content) -> some View {
    content.environment(\.colorScheme, theme == "dark" ? .dark : theme == "light" ? .light : system)
  }
}
struct WidgetBackdrop: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    LinearGradient(colors: scheme == .dark
      ? [Color(white: 0.13), Color(white: 0.075)]
      : [.white, Color(red: 0.97, green: 0.965, blue: 0.99)], startPoint: .topLeading, endPoint: .bottomTrailing)
  }
}
