import LockedInDomain
import SwiftUI

enum CalendarDisplayMode: String { case day, week, month }

struct CalendarMonthGrid: View {
  var day: Date
  var tasks: [TaskRecord]
  var tags: [TagRecord]
  var pendingIDs: Set<UUID>
  var visibleMonthChanged: (Date) -> Void
  var select: (Date) -> Void
  @State private var months: [Date]
  @State private var position: Date?
  private let calendar = Calendar.current

  init(day: Date, tasks: [TaskRecord], tags: [TagRecord], pendingIDs: Set<UUID>, visibleMonthChanged: @escaping (Date) -> Void,
       select: @escaping (Date) -> Void) {
    self.day = day
    self.tasks = tasks
    self.tags = tags
    self.pendingIDs = pendingIDs
    self.visibleMonthChanged = visibleMonthChanged
    self.select = select
    let calendar = Calendar.current
    let month = calendar.dateInterval(of: .month, for: day)!.start
    _months = State(initialValue: (-6...6).compactMap { calendar.date(byAdding: .month, value: $0, to: month) })
    _position = State(initialValue: month)
  }
  var body: some View {
    GeometryReader { geometry in
      let cellHeight = max(76, (geometry.size.height - 64) / 6)
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          ForEach(["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"], id: \.self) { weekday in
            Text(weekday).font(.caption.weight(.medium)).foregroundStyle(.secondary)
              .frame(maxWidth: .infinity).padding(.vertical, 7)
          }
        }
        ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: 16) {
            ForEach(months, id: \.self) { month in
              VStack(alignment: .leading, spacing: 8) {
                Text(month.formatted(.dateTime.month(.wide).year())).font(.headline).padding(.horizontal, 8)
                monthCells(month, height: cellHeight)
              }.id(month)
            }
          }.scrollTargetLayout().padding(.vertical, 8)
        }
        .scrollPosition(id: $position, anchor: .top)
        .onChange(of: position) { _, month in
          guard let month else { return }
          extend(around: month)
          if !calendar.isDate(month, equalTo: day, toGranularity: .month) { visibleMonthChanged(month) }
        }
        .onChange(of: day) { _, date in
          let month = calendar.dateInterval(of: .month, for: date)!.start
          guard position != month else { return }
          extend(around: month)
          withAnimation(.easeInOut(duration: 0.28)) { position = month }
        }
      }
    }
  }
  private func extend(around month: Date) {
    guard let first = months.first, let last = months.last else { return }
    let lower = min(first, calendar.date(byAdding: .month, value: -6, to: month)!)
    let upper = max(last, calendar.date(byAdding: .month, value: 6, to: month)!)
    guard lower != first || upper != last else { return }
    let count = calendar.dateComponents([.month], from: lower, to: upper).month ?? 0
    var transaction = Transaction(); transaction.disablesAnimations = true
    withTransaction(transaction) {
      months = (0...count).compactMap { calendar.date(byAdding: .month, value: $0, to: lower) }
    }
  }
  private func monthCells(_ month: Date, height: CGFloat) -> some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
      ForEach(CalendarMonth.days(containing: month), id: \.self) { date in
        let items = TimelineLayout.placements(tasks: tasks, day: date).map(\.task)
        let current = calendar.isDate(date, equalTo: month, toGranularity: .month)
        Button { select(date) } label: {
          VStack(alignment: .leading, spacing: 4) {
            Text(date.formatted(.dateTime.day())).font(.caption.weight(.semibold))
              .foregroundStyle(calendar.isDateInToday(date) ? Color.white : Color.primary)
              .frame(width: 24, height: 24)
              .background(calendar.isDateInToday(date) ? Color.accent : .clear, in: Circle())
            let limit = height >= 110 ? 3 : 1
            ForEach(items.prefix(limit)) { task in
              Text(task.title).font(.system(size: 10, weight: .medium)).strikethrough(task.completed).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 3).padding(.vertical, 2)
                .foregroundStyle(TaskTagStyle.color(task, tags: tags))
                .background(TaskTagStyle.color(task, tags: tags).opacity(0.12), in: RoundedRectangle(cornerRadius: 3))
                .overlay(alignment: .trailing) { PendingSyncBadge(pending: pendingIDs.contains(task.id)) }
            }
            if items.count > limit {
              Text("+\(items.count - limit)").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
          }.padding(5).frame(maxWidth: .infinity).frame(height: height, alignment: .topLeading)
            .foregroundStyle(.primary).opacity(current ? 1 : 0.4)
            .background(Color.mutedSurface.opacity(current ? 0.7 : 0.3)).contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .complete, time: .omitted) + ", \(items.count) задач")
      }
    }
  }
}
