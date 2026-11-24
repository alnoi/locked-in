#if os(iOS)
import LockedInDomain
import SwiftUI

struct PhoneCalendarMonthFeed: View {
  @Binding var day: Date
  @Binding var rowHeight: CGFloat
  var tasks: [TaskRecord]
  var tags: [TagRecord]
  var pendingIDs: Set<UUID>
  var scrollRequest: Int
  var zoom: Namespace.ID
  var select: (Date) -> Void
  @State private var months: [Date]
  @State private var position: Date?
  @State private var pinchStart: CGFloat?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let calendar = Calendar.current

  init(day: Binding<Date>, rowHeight: Binding<CGFloat>, tasks: [TaskRecord], tags: [TagRecord],
    pendingIDs: Set<UUID>, scrollRequest: Int, zoom: Namespace.ID, select: @escaping (Date) -> Void) {
    _day = day; _rowHeight = rowHeight; self.tasks = tasks; self.tags = tags
    self.pendingIDs = pendingIDs; self.scrollRequest = scrollRequest; self.zoom = zoom; self.select = select
    let calendar = Calendar.current
    let start = calendar.dateInterval(of: .month, for: day.wrappedValue)!.start
    _months = State(initialValue: (-12...12).compactMap { calendar.date(byAdding: .month, value: $0, to: start) })
    _position = State(initialValue: start)
  }
  private var tasksByDay: [Date: [TaskRecord]] {
    Dictionary(grouping: tasks.filter { $0.plannedAt != nil }) { calendar.startOfDay(for: $0.plannedAt!) }
      .mapValues { $0.sorted { ($0.plannedAt ?? .distantPast) < ($1.plannedAt ?? .distantPast) } }
  }
  var body: some View {
    let grouped = tasksByDay
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        ForEach(["П", "В", "С", "Ч", "П", "С", "В"].enumerated().map { ($0.offset, $0.element) }, id: \.0) { index, label in
          Text(label).font(.system(size: 10, weight: .medium)).foregroundStyle(index >= 5 ? .tertiary : .secondary)
            .frame(maxWidth: .infinity).padding(.vertical, 7)
        }
      }.padding(.horizontal, 10)
        .background(Color.mutedSurface, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16).padding(.bottom, 10)
      ScrollViewReader { proxy in
        ScrollView(.vertical) {
          LazyVStack(alignment: .leading, spacing: 14) {
            ForEach(months, id: \.self) { month in
              VStack(alignment: .leading, spacing: 12) {
                Text(month.formatted(.dateTime.month(.wide)).capitalized)
                  .font(.title2.bold())
                  .foregroundStyle(calendar.isDate(month, equalTo: .now, toGranularity: .month) ? Color.accent : .primary)
                  .padding(.horizontal, 8)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                  ForEach(CalendarMonth.days(containing: month), id: \.self) { date in
                    if calendar.isDate(date, equalTo: month, toGranularity: .month) {
                      dateCell(date, items: grouped[date, default: []])
                    } else { Color.clear.frame(height: rowHeight) }
                  }
                }
              }.padding(10)
                .background(Color.mutedSurface, in: RoundedRectangle(cornerRadius: 20))
                .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.055)) }
                .id(month)
            }
          }.scrollTargetLayout().padding(.horizontal, 12).padding(.top, 4).padding(.bottom, 20)
        }
        .scrollPosition(id: $position, anchor: .top)
        .scrollDisabled(pinchStart != nil)
        .onChange(of: position) { _, value in
          guard let value else { return }
          extend(around: value)
          if !calendar.isDate(value, equalTo: day, toGranularity: .month) { day = value }
        }
        .onChange(of: scrollRequest) { _, _ in
          let month = calendar.dateInterval(of: .month, for: day)!.start
          extend(around: month)
          withAnimation(reduceMotion ? nil : .snappy(duration: 0.28)) { proxy.scrollTo(month, anchor: .top) }
        }
        .simultaneousGesture(MagnifyGesture(minimumScaleDelta: 0.01).onChanged { value in
          if pinchStart == nil { pinchStart = rowHeight }
          rowHeight = min(148, max(48, (pinchStart ?? 52) * value.magnification))
        }.onEnded { _ in
          let target = [CGFloat(52), 82, 132].min(by: { abs($0 - rowHeight) < abs($1 - rowHeight) }) ?? 52
          pinchStart = nil
          withAnimation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.88)) { rowHeight = target }
        })
      }
    }
  }
  private func dateCell(_ date: Date, items: [TaskRecord]) -> some View {
    let compact = rowHeight < 66
    let details = rowHeight >= 104
    let limit = details ? max(1, Int((rowHeight - 36) / 18) - 1) : 3
    return Button { select(date) } label: {
      VStack(spacing: compact ? 3 : 5) {
        Text(date.formatted(.dateTime.day())).font(.system(size: 21))
          .frame(width: 32, height: 32)
          .foregroundStyle(calendar.isDateInToday(date) ? Color.white : calendar.isDateInWeekend(date) ? .secondary : .primary)
          .background(calendar.isDateInToday(date) ? Color.accent : .clear, in: RoundedRectangle(cornerRadius: 10))
          .matchedGeometryEffect(id: date, in: zoom, isSource: true)
        if compact {
          HStack(spacing: 2) {
            ForEach(items.prefix(4)) { task in
              Capsule().fill(TaskTagStyle.color(task, tags: tags)).frame(width: 7, height: 3)
                .opacity(task.completed ? 0.4 : 1)
            }
          }.frame(height: 4)
        } else {
          VStack(alignment: .leading, spacing: 2) {
            ForEach(items.prefix(limit)) { task in
              if details {
                Text(task.title).font(.system(size: 9, weight: .medium)).strikethrough(task.completed).lineLimit(1)
                  .padding(.horizontal, 3).frame(maxWidth: .infinity, minHeight: 15, alignment: .leading)
                  .foregroundStyle(TaskTagStyle.color(task, tags: tags))
                  .background(TaskTagStyle.color(task, tags: tags).opacity(0.14), in: RoundedRectangle(cornerRadius: 3))
              } else {
                Capsule().fill(TaskTagStyle.color(task, tags: tags)).frame(height: 4).opacity(task.completed ? 0.4 : 0.8)
              }
            }
            if items.count > limit { Text("+\(items.count - limit)").font(.system(size: 9)).foregroundStyle(.secondary) }
          }.padding(.horizontal, 2)
        }
        Spacer(minLength: 0)
      }.frame(maxWidth: .infinity).frame(height: rowHeight, alignment: .top)
        .overlay(alignment: .topTrailing) {
          if items.contains(where: { pendingIDs.contains($0.id) }) {
            Circle().fill(.red).frame(width: 4, height: 4).padding(3)
          }
        }
        .contentShape(Rectangle())
    }.buttonStyle(.plain)
      .accessibilityLabel(date.formatted(date: .complete, time: .omitted) + ", \(items.count) задач")
  }
  private func extend(around month: Date) {
    guard let first = months.first, let last = months.last else { return }
    let lower = min(first, calendar.date(byAdding: .month, value: -12, to: month)!)
    let upper = max(last, calendar.date(byAdding: .month, value: 12, to: month)!)
    guard lower != first || upper != last else { return }
    let count = calendar.dateComponents([.month], from: lower, to: upper).month ?? 0
    var transaction = Transaction(); transaction.disablesAnimations = true
    withTransaction(transaction) { months = (0...count).compactMap { calendar.date(byAdding: .month, value: $0, to: lower) } }
  }
}
#endif
