import LockedInDomain
import SwiftUI
import WidgetKit

public struct TodayWidgetView: View {
  public let entry: PlannerWidgetEntry
  @Environment(\.widgetFamily) private var systemFamily
  private let previewFamily: WidgetFamily?
  private var family: WidgetFamily { previewFamily ?? systemFamily }
  public init(entry: PlannerWidgetEntry, family: WidgetFamily? = nil) { self.entry = entry; previewFamily = family }
  public var body: some View {
    agenda.widgetURL(URL(string: "lockedin://today")!)
      .environment(\.locale, Locale(identifier: "ru_RU"))
  }
  private var agenda: some View {
    let large = family == .systemLarge
    let limit = large ? 6 : 3
    let tasks = Array(entry.today.prefix(limit))
    return VStack(alignment: .leading, spacing: large ? 12 : 7) {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Сегодня").font(.system(size: 20, weight: .semibold, design: .rounded))
          if large {
            Text(entry.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        Spacer()
        WidgetProgress(completed: entry.completedToday, remaining: entry.today.count)
      }
      if tasks.isEmpty {
        Spacer(minLength: 0)
        WidgetEmpty(connected: entry.snapshot != nil)
        Spacer(minLength: 0)
      } else {
        VStack(spacing: large ? 6 : 3) {
          ForEach(tasks) { task in WidgetTaskRow(task: task, entry: entry, showTag: large) }
        }
        Spacer(minLength: 0)
        if large {
          HStack {
            WidgetBrand()
            Text(entry.today.count > limit ? "Ещё \(entry.today.count - limit) в TrackIt" : "Make room for your life.")
              .font(.system(size: 10)).foregroundStyle(.secondary)
            Spacer()
          }
        }
      }
    }
  }
}
