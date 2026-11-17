import LockedInDomain
import SwiftUI
import WidgetKit

public struct CalendarWidgetView: View {
  public let entry: PlannerWidgetEntry
  @Environment(\.widgetFamily) private var systemFamily
  private let previewFamily: WidgetFamily?
  private var family: WidgetFamily { previewFamily ?? systemFamily }
  private let calendar = Calendar.current
  public init(entry: PlannerWidgetEntry, family: WidgetFamily? = nil) { self.entry = entry; previewFamily = family }
  public var body: some View {
    GeometryReader { geometry in
      if family == .systemLarge {
        VStack(alignment: .leading, spacing: 12) {
          month(large: true).frame(height: geometry.size.height * 0.58)
          Divider().opacity(0.5)
          agenda(limit: 2).frame(maxHeight: .infinity, alignment: .topLeading)
        }
      } else {
        HStack(alignment: .top, spacing: 18) {
          month(large: false).frame(maxWidth: .infinity)
          Rectangle().fill(Color.primary.opacity(0.08)).frame(width: 1)
          agenda(limit: 2).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
      }
    }.widgetURL(WidgetAgenda.calendarURL(entry.date))
      .environment(\.locale, Locale(identifier: "ru_RU"))
  }
  private func month(large: Bool) -> some View {
    let days = CalendarMonth.days(containing: entry.date)
    return GeometryReader { geometry in
    let rows = max(1, days.count / 7)
    let spacing: CGFloat = large ? 2 : 1
    let cellHeight = max(12, (geometry.size.height - (large ? 38 : 30) - CGFloat(rows - 1) * spacing) / CGFloat(rows))
    VStack(spacing: large ? 5 : 4) {
      HStack(spacing: 5) {
        Text(entry.date.formatted(.dateTime.month(.wide))).textCase(.uppercase)
          .font(.system(size: large ? 14 : 11, weight: .bold)).foregroundStyle(Color.widgetAccent).widgetAccentable()
        Spacer(minLength: 0)
        if large { WidgetBrand() }
      }
      HStack(spacing: 0) {
        ForEach(Array(["П", "В", "С", "Ч", "П", "С", "В"].enumerated()), id: \.offset) { _, text in
          Text(text).font(.system(size: 8, weight: .medium)).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
        }
      }
      LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: large ? 2 : 1) {
        ForEach(days, id: \.self) { day in
          let today = calendar.isDate(day, inSameDayAs: entry.date)
          let current = calendar.isDate(day, equalTo: entry.date, toGranularity: .month)
          let tasks = TimelineLayout.placements(tasks: entry.tasks.filter { !$0.completed }, day: day).map(\.task)
          WidgetLink(destination: WidgetAgenda.calendarURL(day)) {
            VStack(spacing: 0) {
              Text(day.formatted(.dateTime.day())).font(.system(size: large ? 12 : 10, weight: today ? .bold : .medium))
                .frame(width: max(10, min(large ? 24 : 17, cellHeight - 2)), height: max(10, min(large ? 24 : 17, cellHeight - 2)))
                .foregroundStyle(today ? Color.white : Color.primary)
                .background(today ? Color.widgetAccent : .clear, in: Circle())
              HStack(spacing: 2) {
                ForEach(Array(tasks.prefix(3).enumerated()), id: \.offset) { _, task in
                  let tag = entry.snapshot?.tags.first { task.tagIDs.contains($0.id) }
                  Circle().fill(Color(widgetHex: tag?.color)).frame(width: 2, height: 2)
                }
              }.frame(height: 2)
            }.frame(maxWidth: .infinity).frame(height: cellHeight).opacity(current ? 1 : 0.25)
          }.accessibilityLabel(day.formatted(date: .complete, time: .omitted) + ", задач: \(tasks.count)")
        }
      }
    }
    }
  }
  private func agenda(limit: Int) -> some View {
    let tasks = TimelineLayout.placements(tasks: entry.tasks.filter { !$0.completed }, day: entry.date).map(\.task)
    return VStack(alignment: .leading, spacing: 9) {
      HStack {
        Text("Сегодня").font(.system(size: 12, weight: .semibold))
        Spacer(minLength: 0)
        if family != .systemLarge { WidgetBrand() }
      }
      if entry.snapshot == nil {
        Text("Открой TrackIt, чтобы увидеть расписание.").font(.caption).foregroundStyle(.secondary)
      } else if tasks.isEmpty {
        VStack(alignment: .leading, spacing: 5) {
          Image(systemName: "sun.max").font(.system(size: 19, weight: .light)).foregroundStyle(Color.widgetAccent)
          Text("Свободный день").font(.system(size: 12, weight: .medium))
          Text("Время для твоих планов").font(.system(size: 10)).foregroundStyle(.secondary)
        }.padding(.top, 5)
      } else {
        ForEach(tasks.prefix(limit)) { task in
          WidgetLink(destination: WidgetAgenda.taskURL(task.id)) {
            HStack(spacing: 7) {
              let tag = entry.snapshot?.tags.first { task.tagIDs.contains($0.id) }
              let color = Color(widgetHex: tag?.color)
              RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3)
              VStack(alignment: .leading, spacing: 2) {
                if let start = task.plannedAt {
                  Text(start, style: .time).font(.system(size: 10, weight: .semibold)).monospacedDigit().foregroundStyle(color)
                }
                Text(task.title).font(.system(size: 12, weight: .medium)).foregroundStyle(.primary)
                  .lineLimit(family == .systemLarge ? 1 : 2)
              }.frame(maxWidth: .infinity, alignment: .leading)
            }.fixedSize(horizontal: false, vertical: true)
          }
        }
        if tasks.count > limit { Text("Ещё \(tasks.count - limit)").font(.system(size: 10)).foregroundStyle(.secondary) }
      }
      Spacer(minLength: 0)
    }
  }
}
