import SwiftUI
import LockedInDomain

struct CalendarWorkspace: View {
    @Bindable var model: AppModel
    var search: String
    var showCompleted: Bool
    var focus: CalendarTaskFocus?
    var open: (TaskRecord) -> Void
    var create: (Date) -> Void
    @State private var day = Calendar.current.startOfDay(for: Date())
    #if os(macOS)
    @State private var mode: CalendarDisplayMode = .week
    #else
    @State private var mode: CalendarDisplayMode = .day
    #endif
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pageDirection = CalendarPageDirection()
    @State private var isPaging = false
    @State private var interaction: CalendarTaskInteraction?
    @State private var pickDate = false
    @State private var showUnplanned = true
    private let calendar = Calendar.current
    private let timelineOnly: Bool
    private let selectedDay: Date?
    private let timelineScale: CGFloat
    private var hourHeight: CGFloat { 60 * timelineScale }
    init(model: AppModel, search: String, showCompleted: Bool, focus: CalendarTaskFocus? = nil,
      open: @escaping (TaskRecord) -> Void, create: @escaping (Date) -> Void,
      timelineOnly: Bool = false, selectedDay: Date? = nil, timelineScale: CGFloat = 1) {
      self.model = model; self.search = search; self.showCompleted = showCompleted
      self.focus = focus; self.open = open; self.create = create
      self.timelineOnly = timelineOnly; self.selectedDay = selectedDay
      self.timelineScale = timelineScale
      _day = State(initialValue: Calendar.current.startOfDay(for: selectedDay ?? focus?.date ?? .now))
      #if os(macOS)
      _mode = State(initialValue: focus == nil ? .week : .day)
      #else
      _mode = State(initialValue: .day)
      #endif
    }
    private var scrollHour: Int {
      let date = focus.flatMap { calendar.isDate($0.date, inSameDayAs: day) ? $0.date : nil } ?? .now
      return max(0, calendar.component(.hour, from: date) - 1)
    }
    private var week: [Date] {
        var calendar = self.calendar; calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: day)!.start
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }
    private var tasks: [TaskRecord] { model.snapshot.tasks.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) } }
    private var periodID: String {
      if mode == .month { return "month-feed" }
      let component: Calendar.Component = mode == .month ? .month : (mode == .week ? .weekOfYear : .day)
      var mondayCalendar = calendar; mondayCalendar.firstWeekday = 2
      let start = mondayCalendar.dateInterval(of: component, for: day)?.start ?? day
      return mode.rawValue + ":" + String(start.timeIntervalSinceReferenceDate)
    }
    private var periodTransition: AnyTransition {
      reduceMotion ? .opacity : .asymmetric(
        insertion: .modifier(active: CalendarPageSlide(progress: 1, direction: pageDirection),
          identity: CalendarPageSlide(progress: 0, direction: pageDirection)),
        removal: .modifier(active: CalendarPageSlide(progress: -1, direction: pageDirection),
          identity: CalendarPageSlide(progress: 0, direction: pageDirection)))
    }
    var body: some View {
        let displayedDates = mode == .week ? week : [day]
        let displayedWeek = mode == .week
        VStack(spacing: 0) {
            if !timelineOnly {
              calendarHeader.modifier(CalendarPeriodSwipe(enabled: interaction == nil, shift: shift))
              if showUnplanned && !tasks.filter({ $0.plannedAt == nil }).isEmpty { unplanned }
              Divider()
            }
            ZStack {
            Group {
            if mode == .month {
              CalendarMonthGrid(day: day, tasks: tasks, tags: model.snapshot.tags, pendingIDs: model.visibleUnsyncedTaskIDs, visibleMonthChanged: { day = $0 }) { date in
                selectDate(date)
                mode = .day
              }
            } else {
            GeometryReader { viewport in
                let dates = displayedDates
                #if os(macOS)
                let minimumWidth: CGFloat = displayedWeek ? 120 : 250
                #else
                let minimumWidth: CGFloat = displayedWeek ? 155 : 250
                #endif
                let width = max(viewport.size.width, CGFloat(dates.count) * minimumWidth + 48)
                Group {
                        VStack(spacing: 0) {
                            if displayedWeek {
                            HStack(spacing: 0) {
                                Color.clear.frame(width: 48, height: 1)
                                ForEach(dates, id: \.self) { date in
                                    Text(date.formatted(.dateTime.weekday(.abbreviated).day())).font(.caption.weight(.semibold))
                                        .foregroundStyle(calendar.isDateInToday(date) ? Color.accent : .secondary)
                                        .frame(maxWidth: .infinity).padding(.vertical, 12)
                                }
                            }
                            }
                            ScrollViewReader { proxy in
                              ScrollView(.vertical) {
                               ZStack(alignment: .topLeading) {
                                VStack(spacing: 0) {
                                    ForEach(0..<24) { hour in
                                        HStack(alignment: .top, spacing: 0) {
                                            Text(String(format: "%02d:00", hour)).font(.caption2.monospacedDigit()).foregroundStyle(.tertiary)
                                                .frame(width: 44, alignment: .trailing).padding(.trailing, 4)
                                            Rectangle().fill(Color.primary.opacity(0.065)).frame(height: 1)
                                        }.frame(height: hourHeight, alignment: .top).id("hour-\(hour)")
                                    }
                                }
                                HStack(spacing: 0) {
                                    Color.clear.frame(width: 48)
                                    ForEach(dates, id: \.self) { date in timelineDay(date, dates: dates, width: (width - 48) / CGFloat(dates.count)) }
                                }
                                if let interaction {
                                  CalendarInteractionShadow(task: interaction.task, duration: interaction.duration)
                                    .frame(width: interaction.frame.width, height: interaction.frame.height)
                                    .background(TaskTagStyle.color(interaction.task, tags: model.snapshot.tags).opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                                    .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(TaskTagStyle.color(interaction.task, tags: model.snapshot.tags).opacity(0.6)) }
                                    .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
                                    .opacity(interaction.settling ? 1 : 0.62)
                                    .offset(x: interaction.frame.minX, y: interaction.frame.minY)
                                    .allowsHitTesting(false)
                                }
                               }.coordinateSpace(name: "calendarTimeline")
                               .frame(height: hourHeight * 24).padding(.bottom,16)
                              }
                              .onAppear { proxy.scrollTo("hour-\(scrollHour)",anchor: .topLeading) }
                              .onChange(of: day) { _,_ in proxy.scrollTo("hour-\(scrollHour)",anchor: .topLeading) }
                              .onChange(of: focus?.id) { _,_ in proxy.scrollTo("hour-\(scrollHour)",anchor: .topLeading) }
                            }.frame(height: max(1,viewport.size.height - (displayedWeek ? 40 : 0)))
                        }.frame(width: width)
                }.modifier(CalendarTimelineHorizontalScroll(enabled: !timelineOnly))
            }
            }
            }.id(periodID).transition(periodTransition)
            }.clipped()
              .modifier(CalendarPeriodSwipe(enabled: !timelineOnly && interaction == nil && mode != .month, shift: shift))
        }.onChange(of: mode) { _, _ in cancelInteraction() }
        .onChange(of: selectedDay) { _, value in
          guard let value, !calendar.isDate(value, inSameDayAs: day) else { return }
          cancelInteraction()
          pageDirection.sign = value > day ? 1 : -1
          day = calendar.startOfDay(for: value)
        }
        .onChange(of: focus?.id) { _, _ in
          guard let focus else { return }
          cancelInteraction()
          day = calendar.startOfDay(for: selectedDay ?? focus.date)
          mode = .day
        }
        .background {
          AppShortcutHandler(priority: 10, enabled: !timelineOnly && interaction == nil && !pickDate) { shortcut in
            switch shortcut {
            case .previousPeriod: shift(-1)
            case .nextPeriod: shift(1)
            case .today: selectDate(calendar.startOfDay(for: .now))
            case .day: setMode(.day)
            case .week: setMode(.week)
            case .month: setMode(.month)
            default: return false
            }
            return true
          }.allowsHitTesting(false)
        }
    }
    private var calendarHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Button { pickDate = true } label: { HStack(spacing: 5) { Text(day.formatted(.dateTime.month(.wide).year())).font(.title2.bold()).lineLimit(1).minimumScaleFactor(0.65); Image(systemName: "chevron.down").font(.caption) } }.buttonStyle(.plain)
                    .popover(isPresented: $pickDate) { DatePicker("Дата", selection: Binding(get: { day }, set: selectDate), displayedComponents: .date).datePickerStyle(.graphical).padding().frame(minWidth: 300) }
                Spacer(minLength: 0)
                Picker("Вид", selection: Binding(get: { mode }, set: { value in
                  guard !isPaging else { return }
                  withAnimation(.easeInOut(duration: 0.18)) { mode = value }
                })) {
                  Text("День").tag(CalendarDisplayMode.day)
                  Text("Неделя").tag(CalendarDisplayMode.week)
                  Text("Месяц").tag(CalendarDisplayMode.month)
                }.pickerStyle(.segmented).labelsHidden().frame(maxWidth: 250)
            }
            HStack {
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }.buttonStyle(.plain).accessibilityLabel("Предыдущий период")
                Button("Сегодня") { selectDate(calendar.startOfDay(for: .now)) }.buttonStyle(.bordered).controlSize(.small)
                Button { shift(1) } label: { Image(systemName: "chevron.right") }.buttonStyle(.plain).accessibilityLabel("Следующий период")
                Spacer()
                Button { withAnimation { showUnplanned.toggle() } } label: { Label("Без времени", systemImage: showUnplanned ? "tray.fill" : "tray") }.font(.caption).buttonStyle(.plain).foregroundStyle(.secondary)
            }
            if mode == .day {
                HStack(spacing: 6) {
                    ForEach(week, id: \.self) { date in
                        let selected = calendar.isDate(date, inSameDayAs: day)
                        Button { selectDate(date) } label: {
                            VStack(spacing: 2) { Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.caption2); Text(date.formatted(.dateTime.day())).font(.headline) }
                                .frame(maxWidth: .infinity).padding(.vertical, 4)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(selected ? Color.accent : Color.clear, in: RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }.padding(20)
    }
    private var unplanned: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "tray").foregroundStyle(.secondary)
                ForEach(tasks.filter { $0.plannedAt == nil && (showCompleted || !$0.completed) }) { task in
                    Button { open(task) } label: { Text(task.title).font(.caption.weight(.medium)).lineLimit(2).truncationMode(.tail).multilineTextAlignment(.leading).frame(width: 170, height: 32, alignment: .leading).padding(.horizontal, 12).padding(.vertical, 8).foregroundStyle(TaskTagStyle.color(task, tags: model.snapshot.tags)).background(TaskTagStyle.color(task, tags: model.snapshot.tags).opacity(0.12), in: RoundedRectangle(cornerRadius: 12)).overlay(alignment: .topTrailing) { PendingSyncBadge(pending: model.visibleUnsyncedTaskIDs.contains(task.id)).padding(4) } }
                        .buttonStyle(.plain).draggable(task.id.uuidString)
                }
            }.padding(.horizontal, 20).padding(.bottom, 12)
        }
    }
    private func timelineDay(_ date: Date, dates: [Date], width: CGFloat) -> some View {
        let placements = TimelineLayout.placements(tasks: tasks, day: date)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(0..<24) { hour in
                    Color.clear.frame(height: hourHeight).contentShape(Rectangle())
                        .onTapGesture(count: 2) { if model.canEdit { create(time(date, hour: hour, minute: 0)) } }
                        .dropDestination(for: String.self) { values, location in
                            guard model.canEdit, values.count == 1, let id = UUID(uuidString: values[0]), model.snapshot.tasks.contains(where: { $0.id == id }) else { return false }
                            let duration = Double(tasks.first(where: { $0.id == id })?.durationMinutes ?? 60)
                            let neighbors = placements.filter { $0.id != id }
                            let edges = neighbors.flatMap { [$0.startMinute + $0.durationMinutes, $0.startMinute - duration] }
                            let raw = Double(hour * 60) + Double(location.y / hourHeight * 60)
                            let minute = Int(CalendarSnapping.minute(raw, boundaries: edges, maximum: max(0, 1440 - duration)))
                            model.schedule(id, at: time(date, hour: minute / 60, minute: minute % 60)); return true
                        }
                }
            }
            Rectangle().fill(Color.primary.opacity(0.05)).frame(width: 1)
            ForEach(placements) { placement in
                let cardWidth = max(1, (width - 6) / CGFloat(placement.columns) - 3)
                let cardHeight = max(20, CGFloat(placement.durationMinutes) / 60 * hourHeight - 3)
                let x = 3 + (width - 6) / CGFloat(placement.columns) * CGFloat(placement.column)
                let y = CGFloat(placement.startMinute) / 60 * hourHeight
                CalendarTaskBlock(model: model, task: placement.task, open: { open(placement.task) },
                  changed: { translation, resizing in
                    updateInteraction(task: placement.task, date: date, dates: dates, width: width,
                      frame: CGRect(x: 48 + CGFloat(dates.firstIndex(of: date) ?? 0) * width + x,
                        y: y, width: cardWidth, height: cardHeight), translation: translation, resizing: resizing)
                  }, ended: { finishInteraction(dates: dates, width: width) }, cancelled: cancelInteraction)
                    .frame(width: cardWidth, height: cardHeight)
                    .opacity(interaction?.task.id == placement.id ? 0.18 : 1)
                    .offset(x: x, y: y)
            }
            if calendar.isDateInToday(date) {
                TimelineView(.periodic(from: .now, by: 60)) { tick in
                    let parts = calendar.dateComponents([.hour, .minute], from: tick.date)
                    HStack(spacing: 0) {
                      Circle().fill(timelineOnly ? Color.accent : .red).frame(width: 5, height: 5)
                      Rectangle().fill(timelineOnly ? Color.accent : .red).frame(height: 1)
                    }
                        .offset(y: CGFloat((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / 60 * hourHeight)
                }.allowsHitTesting(false)
            }
        }.frame(width: width, height: hourHeight * 24)
    }
    private func cancelInteraction() {
      guard interaction?.settling != true else { return }
      interaction = nil
    }
    private func updateInteraction(task: TaskRecord, date: Date, dates: [Date], width: CGFloat,
      frame: CGRect, translation: CGSize, resizing: Bool) {
      guard model.canEdit, interaction?.settling != true else { return }
      if interaction == nil {
        interaction = CalendarTaskInteraction(task: task, date: date, originalFrame: frame,
          frame: frame, resizing: resizing, duration: task.durationMinutes ?? 60)
      }
      guard var value = interaction, value.task.id == task.id else { return }
      value.translation = translation
      if resizing {
        // Only the shadow changes size. The gesture's own view stays stationary.
        value.frame.size.height = max(20, value.originalFrame.height + translation.height)
        value.duration = max(15, Int((value.frame.height + 3) / hourHeight * 60))
      } else {
        value.frame.origin.x = value.originalFrame.minX + translation.width
        value.frame.origin.y = value.originalFrame.minY + translation.height
      }
      var transaction = Transaction(); transaction.disablesAnimations = true
      withTransaction(transaction) { interaction = value }
    }
    private func finishInteraction(dates: [Date], width: CGFloat) {
      guard var value = interaction, !value.settling else { return }
      let targetIndex = value.resizing ? (dates.firstIndex(of: value.date) ?? 0)
        : min(dates.count - 1, max(0, Int(floor((value.frame.midX - 48) / width))))
      let date = dates[targetIndex]
      let neighbors = TimelineLayout.placements(tasks: tasks.filter { $0.id != value.task.id }, day: date)
      var input = TaskInput(value.task)
      let originalStart = value.originalFrame.minY / hourHeight * 60
      var minute = originalStart
      if value.resizing {
        let rawEnd = originalStart + Double(value.task.durationMinutes ?? 60) + Double(value.translation.height / hourHeight * 60)
        let end = CalendarSnapping.minute(rawEnd,
          boundaries: neighbors.flatMap { [$0.startMinute, $0.startMinute + $0.durationMinutes] },
          minimum: originalStart + 15, maximum: 1440)
        input.durationMinutes = Int(end - originalStart)
      } else {
        let duration = Double(value.task.durationMinutes ?? 60)
        minute = CalendarSnapping.minute(Double(value.frame.minY / hourHeight * 60),
          boundaries: neighbors.flatMap { [$0.startMinute + $0.durationMinutes, $0.startMinute - duration] },
          maximum: max(0, 1440 - duration))
        input.plannedAt = time(date, hour: Int(minute) / 60, minute: Int(minute) % 60)
        if input.durationMinutes == nil { input.durationMinutes = 60 }
      }
      var projected = value.task
      projected.plannedAt = input.plannedAt
      projected.durationMinutes = input.durationMinutes
      let placements = TimelineLayout.placements(tasks: tasks.filter { $0.id != projected.id } + [projected], day: date)
      if let placement = placements.first(where: { $0.id == projected.id }) {
        value.frame = CGRect(x: 48 + CGFloat(targetIndex) * width + 3 + (width - 6) / CGFloat(placement.columns) * CGFloat(placement.column),
          y: CGFloat(placement.startMinute) / 60 * hourHeight,
          width: max(1, (width - 6) / CGFloat(placement.columns) - 3),
          height: max(20, CGFloat(placement.durationMinutes) / 60 * hourHeight - 3))
      }
      value.duration = input.durationMinutes ?? 60
      value.settling = true
      let token = value.token
      withAnimation(.snappy(duration: 0.18, extraBounce: 0)) { interaction = value }
      Task { @MainActor in
        let animation = Task { try? await Task.sleep(for: .milliseconds(180)) }
        do {
          try await model.mutate(.task(value.task.id, input))
          await animation.value
        } catch {
          model.errorMessage = model.friendly(error)
          if interaction?.token == token {
            withAnimation(.easeOut(duration: 0.12)) { interaction?.frame = value.originalFrame }
            try? await Task.sleep(for: .milliseconds(120))
          }
        }
        guard interaction?.token == token else { return }
        var transaction = Transaction(); transaction.disablesAnimations = true
        withTransaction(transaction) { interaction = nil }
      }
    }
    private func selectDate(_ date: Date) {
      guard interaction == nil, !isPaging, date != day else { return }
      pageDirection.sign = date > day ? 1 : -1
      isPaging = true
      withAnimation(reduceMotion ? .easeOut(duration: 0.15) : .easeInOut(duration: 0.18)) {
        day = date
      } completion: {
        isPaging = false
      }
    }
    private func setMode(_ value: CalendarDisplayMode) {
      guard !isPaging, interaction == nil else { return }
      withAnimation(.easeInOut(duration: 0.18)) { mode = value }
    }
    private func shift(_ amount: Int) {
      guard interaction == nil else { return }
      selectDate(calendar.date(byAdding: mode == .month ? .month : .day,
        value: amount * (mode == .week ? 7 : 1), to: day) ?? day)
    }
    private func time(_ date: Date, hour: Int, minute: Int) -> Date { calendar.date(bySettingHour: hour, minute: minute, second: 0, of: date)! }
}
private struct CalendarTaskInteraction {
    let token = UUID()
    var task: TaskRecord
    var date: Date
    var originalFrame: CGRect
    var frame: CGRect
    var resizing: Bool
    var duration: Int
    var translation: CGSize = .zero
    var settling = false
}
private struct CalendarInteractionShadow: View {
    var task: TaskRecord
    var duration: Int
    var body: some View {
      VStack(alignment: .leading, spacing: 3) {
        Text(task.title).font(.caption.weight(.semibold)).strikethrough(task.completed).lineLimit(2)
        Text("\(duration) мин").font(.system(size: 10)).foregroundStyle(.secondary)
      }.padding(7).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).clipped()
    }
}
private struct CalendarTaskBlock: View {
    @Bindable var model: AppModel
    var task: TaskRecord
    var open: () -> Void
    var changed: (CGSize, Bool) -> Void
    var ended: () -> Void
    var cancelled: () -> Void
    @GestureState private var tracking = false
    private var color: Color { TaskTagStyle.color(task, tags: model.snapshot.tags) }
    private func drag(resizing: Bool) -> some Gesture {
      #if os(iOS)
      LongPressGesture(minimumDuration: 0.3, maximumDistance: 10)
        .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("calendarTimeline")))
        .updating($tracking) { value, state, _ in
          if case .second(true, _) = value { state = true }
        }
        .onChanged { value in
          if case .second(true, let drag?) = value { changed(drag.translation, resizing) }
        }
        .onEnded { value in
          if case .second(true, _) = value { ended() }
        }
      #else
      DragGesture(minimumDistance: 3, coordinateSpace: .named("calendarTimeline"))
        .updating($tracking) { _, state, _ in state = true }
        .onChanged { changed($0.translation, resizing) }
        .onEnded { _ in ended() }
      #endif
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .top, spacing: 3) {
                  Text(task.title).font(.caption.weight(.semibold)).strikethrough(task.completed).lineLimit(geometry.size.height > 65 ? 2 : 1)
                  PendingSyncBadge(pending: model.visibleUnsyncedTaskIDs.contains(task.id))
                }
                if geometry.size.height > 42, let start = task.plannedAt {
                  Text(start.formatted(date: .omitted, time: .shortened) + (task.durationMinutes.map { " · \($0) мин" } ?? "")).font(.system(size: 10)).lineLimit(1)
                }
            }.padding(.horizontal, 7).padding(.top, 4).padding(.bottom, 10).foregroundStyle(color)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3).padding(.vertical, 5) }.clipped()
                .contentShape(Rectangle()).onTapGesture(perform: open)
                .gesture(drag(resizing: false), including: model.canEdit ? .all : .none)
                .overlay(alignment: .bottom) {
                  if model.canEdit {
                    Capsule().fill(color.opacity(0.45)).frame(width: 24, height: 3)
                      .frame(maxWidth: .infinity).padding(.vertical, 4).contentShape(Rectangle())
                      .highPriorityGesture(drag(resizing: true)).accessibilityLabel("Изменить длительность")
                  }
                }
                .contextMenu {
                    Button("Открыть", action: open)
                    Button(task.completed ? "Вернуть в работу" : "Завершить") { model.perform(.completed(task.id, !task.completed)) }.disabled(!model.canEdit)
                    Button("Убрать из календаря") { var input = TaskInput(task); input.plannedAt = nil; model.perform(.task(task.id, input)) }.disabled(!model.canEdit)
                }
        }.onChange(of: tracking) { _, active in if !active { cancelled() } }
    }
}

private struct CalendarTimelineHorizontalScroll: ViewModifier {
  var enabled: Bool
  func body(content: Content) -> some View {
    if enabled { ScrollView(.horizontal) { content } }
    else { content }
  }
}
