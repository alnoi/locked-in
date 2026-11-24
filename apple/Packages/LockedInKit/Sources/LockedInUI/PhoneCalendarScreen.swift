import LockedInDomain
import SwiftUI

struct CalendarScreen: View {
  @Bindable var model: AppModel
  var search: String
  var showCompleted: Bool
  var focus: CalendarTaskFocus? = nil
  var open: (TaskRecord) -> Void
  var create: (Date) -> Void
  var back: (() -> Void)? = nil
  var forward: (() -> Void)? = nil
  var position: PhoneCalendarPosition? = nil
  var positionChanged: ((PhoneCalendarPosition) -> Void)? = nil
  var body: some View {
    #if os(iOS)
    PhoneCalendarScreen(model: model, search: search, showCompleted: showCompleted,
      focus: focus, open: open, create: create, back: back, forward: forward,
      position: position, positionChanged: positionChanged)
    #else
    CalendarWorkspace(model: model, search: search, showCompleted: showCompleted,
      focus: focus, open: open, create: create)
    #endif
  }
}

#if os(iOS)
struct PhoneCalendarScreen: View {
  @Bindable var model: AppModel
  var search: String
  var showCompleted: Bool
  var focus: CalendarTaskFocus?
  var open: (TaskRecord) -> Void
  var create: (Date) -> Void
  var back: (() -> Void)?
  var forward: (() -> Void)?
  var positionChanged: ((PhoneCalendarPosition) -> Void)?
  @State private var day: Date
  @State private var monthMode: Bool
  @State private var monthRowHeight: CGFloat = 52
  @State private var dayScale: CGFloat = 1
  @State private var pinchStart: CGFloat?
  @State private var showUnplanned = false
  @State private var scrollRequest = 0
  @Namespace private var dateZoom
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  private let calendar = Calendar.current

  init(model: AppModel, search: String, showCompleted: Bool, focus: CalendarTaskFocus?,
    open: @escaping (TaskRecord) -> Void, create: @escaping (Date) -> Void, back: (() -> Void)? = nil, forward: (() -> Void)? = nil,
    position: PhoneCalendarPosition? = nil, positionChanged: ((PhoneCalendarPosition) -> Void)? = nil) {
    self.model = model; self.search = search; self.showCompleted = showCompleted
    self.focus = focus; self.open = open; self.create = create; self.back = back; self.forward = forward
    self.positionChanged = positionChanged
    _day = State(initialValue: Calendar.current.startOfDay(for: position?.date ?? focus?.date ?? .now))
    _monthMode = State(initialValue: position?.monthMode ?? false)
  }
  private var tasks: [TaskRecord] {
    model.snapshot.tasks.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) }
  }
  private var unplanned: [TaskRecord] { tasks.filter { $0.plannedAt == nil && (showCompleted || !$0.completed) } }
  private var week: [Date] {
    var monday = calendar; monday.firstWeekday = 2
    let start = monday.dateInterval(of: .weekOfYear, for: day)!.start
    return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
  }
  var body: some View {
    VStack(spacing: 0) {
      if monthMode {
        HStack {
          Text(day.formatted(.dateTime.year())).font(.system(size: 17, weight: .medium)).foregroundStyle(Color.accent)
          Spacer()
        }.padding(.horizontal, 20).padding(.vertical, 8)
      } else {
        dayHeader
      }
      ZStack {
        if monthMode {
          PhoneCalendarMonthFeed(day: $day, rowHeight: $monthRowHeight, tasks: tasks,
            tags: model.snapshot.tags, pendingIDs: model.visibleUnsyncedTaskIDs,
            scrollRequest: scrollRequest, zoom: dateZoom, select: selectDay)
            .modifier(CalendarPeriodSwipe(enabled: back != nil || forward != nil) { direction in
              if direction < 0 { back?() } else { forward?() }
            })
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
        } else {
          PhoneCalendarDayPager(day: $day) { date in
            CalendarWorkspace(model: model, search: search, showCompleted: showCompleted,
              focus: focus, open: open, create: create, timelineOnly: true,
              selectedDay: date, timelineScale: dayScale)
          }
            .simultaneousGesture(MagnifyGesture().onChanged { value in
              if pinchStart == nil { pinchStart = dayScale }
              dayScale = min(2, max(0.65, (pinchStart ?? 1) * value.magnification))
            }.onEnded { _ in pinchStart = nil })
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 16)))
        }
      }.frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
      if showUnplanned && !unplanned.isEmpty { unplannedRibbon.transition(.move(edge: .bottom).combined(with: .opacity)) }
      bottomBar
    }
    .toolbar {
      ToolbarItemGroup(placement: .primaryAction) {
        Menu {
          Button { switchMode(false) } label: { Label("День", systemImage: monthMode ? "square" : "checkmark") }
          Button { switchMode(true) } label: { Label("Месяц", systemImage: monthMode ? "checkmark" : "square") }
        } label: { Image(systemName: monthMode ? "rectangle.grid.1x2" : "calendar") }
          .accessibilityLabel("Вид календаря")
        Button {
          let now = calendar.dateComponents([.hour, .minute], from: .now)
          create(calendar.date(bySettingHour: now.hour ?? 9, minute: now.minute ?? 0, second: 0, of: day) ?? day)
        } label: { Image(systemName: "plus") }.disabled(!model.canEdit).accessibilityLabel("Новая задача в календаре")
      }
    }
    .tint(Color.accent)
    .onAppear { reportPosition() }
    .onChange(of: day) { _, _ in reportPosition() }
    .onChange(of: monthMode) { _, _ in reportPosition() }
    .onChange(of: focus?.id) { _, _ in
      guard let focus else { return }
      day = calendar.startOfDay(for: focus.date)
      switchMode(false)
    }
  }
  private var dayHeader: some View {
    VStack(alignment: .leading, spacing: 10) {
      Button { switchMode(true) } label: {
        HStack(spacing: 5) {
          Image(systemName: "calendar").font(.system(size: 14, weight: .semibold))
          Text(day.formatted(.dateTime.month(.wide))).font(.system(size: 19, weight: .semibold))
        }.foregroundStyle(Color.accent)
      }.buttonStyle(.plain).accessibilityLabel("Показать месяц")
      HStack(spacing: 0) {
        ForEach(week, id: \.self) { date in
          let selected = calendar.isDate(date, inSameDayAs: day)
          Button { selectDay(date) } label: {
            VStack(spacing: 3) {
              Text(date.formatted(.dateTime.weekday(.narrow))).font(.system(size: 10, weight: .medium))
                .foregroundStyle(calendar.isDateInWeekend(date) ? .secondary : .primary)
              Text(date.formatted(.dateTime.day())).font(.system(size: 22, weight: selected ? .semibold : .regular))
                .frame(width: 36, height: 36)
                .foregroundStyle(selected ? Color.white : calendar.isDateInToday(date) ? .accent : .primary)
                .background(selected ? Color.accent : .clear, in: RoundedRectangle(cornerRadius: 12))
                .matchedGeometryEffect(id: date, in: dateZoom, isSource: false)
            }.frame(maxWidth: .infinity).padding(.vertical, 3).contentShape(Rectangle())
          }.buttonStyle(.plain).accessibilityLabel(date.formatted(date: .complete, time: .omitted))
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
      }.modifier(CalendarPeriodSwipe(enabled: true) { offset in
        if let next = calendar.date(byAdding: .day, value: offset * 7, to: day) { selectDay(next) }
      })
      Text(day.formatted(.dateTime.weekday(.wide).day().month(.wide)))
        .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
    }.padding(.horizontal, 16).padding(.top, 6).padding(.bottom, 10)
      .background(Color.mutedSurface).overlay(alignment: .bottom) { Color.primary.opacity(0.06).frame(height: 1) }
  }
  private var bottomBar: some View {
    HStack {
      Button("Сегодня") {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) {
          day = calendar.startOfDay(for: .now)
          scrollRequest += 1
        }
      }.font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.accent)
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Color.accent.opacity(0.1), in: Capsule())
      Spacer()
      if !unplanned.isEmpty {
        Button {
          withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { showUnplanned.toggle() }
        } label: {
          Label("Без времени · \(unplanned.count)", systemImage: showUnplanned ? "tray.fill" : "tray")
            .font(.system(size: 13, weight: .medium)).foregroundStyle(showUnplanned ? Color.accent : .secondary)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(showUnplanned ? Color.accent.opacity(0.1) : Color.mutedSurface, in: Capsule())
        }
      }
    }.buttonStyle(.plain).padding(.horizontal, 16).padding(.vertical, 10)
      .background(.ultraThinMaterial).overlay(alignment: .top) { Color.primary.opacity(0.06).frame(height: 1) }
  }
  private var unplannedRibbon: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(unplanned) { task in
          Button { open(task) } label: {
            Text(task.title).font(.system(size: 12, weight: .medium)).lineLimit(2)
              .frame(width: 144, height: 32, alignment: .leading).padding(10)
              .foregroundStyle(TaskTagStyle.color(task, tags: model.snapshot.tags))
              .background(TaskTagStyle.color(task, tags: model.snapshot.tags).opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
          }.buttonStyle(.plain).draggable(task.id.uuidString)
        }
      }.padding(.horizontal, 16).padding(.vertical, 8)
    }.background(Color.mutedSurface)
  }
  private func reportPosition() {
    positionChanged?(PhoneCalendarPosition(date: day, monthMode: monthMode))
  }
  private func selectDay(_ value: Date) {
    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9)) {
      day = calendar.startOfDay(for: value)
      monthMode = false
    }
  }
  private func switchMode(_ month: Bool) {
    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.9)) { monthMode = month }
  }
}
#endif
