import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \PlannerTask.start) private var tasks: [PlannerTask]
    @State private var day = Calendar.current.startOfDay(for: Date())
    @State private var draft: TaskDraft?
    @State private var errorMessage: String?
    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 84

    private var nextDay: Date { calendar.date(byAdding: .day, value: 1, to: day)! }
    private var dayTasks: [PlannerTask] { tasks.filter { $0.start < nextDay && $0.end > day } }
    private var week: [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: day)!.start
        return (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                timeline
            }
            .navigationTitle("Мой день")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { addTask() } label: { Label("Новая задача", systemImage: "plus") }
                        .keyboardShortcut("n", modifiers: .command)
                }
            }
            .sheet(item: $draft) { TaskEditor(draft: $0) }
            .alert("Не удалось сохранить", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("Понятно") { errorMessage = nil }
            } message: { Text(errorMessage ?? "") }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.formatted(.dateTime.day().month(.wide)))
                        .font(.title2.bold())
                    Text(dayTasks.isEmpty ? "Свободный день. Что запланируем?" : "Завершено \(dayTasks.filter(\.completed).count) из \(dayTasks.count)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Сегодня") { day = calendar.startOfDay(for: Date()) }
                    .buttonStyle(.bordered)
                Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Предыдущий день")
                Button { shift(1) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Следующий день")
            }
            HStack(spacing: 4) {
                ForEach(week, id: \.self) { date in
                    let selected = calendar.isDate(date, inSameDayAs: day)
                    Button { day = calendar.startOfDay(for: date) } label: {
                        VStack(spacing: 7) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated))).font(.caption)
                            Text(date.formatted(.dateTime.day())).font(.headline)
                            Circle().fill(calendar.isDateInToday(date) ? (selected ? Color.white : .indigo) : .clear)
                                .frame(width: 4, height: 4)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 10)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .background(selected ? Color.indigo : Color.clear, in: RoundedRectangle(cornerRadius: 16))
                        .contentShape(Rectangle())
                    }.buttonStyle(.plain)
                        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
        }.padding(20)
    }

    private var timeline: some View {
        ScrollViewReader { proxy in
            ScrollView {
                GeometryReader { geometry in
                    let layouts = placements()
                    let usable = max(geometry.size.width - 68, 1)
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                          ForEach(0..<24) { hour in
                            HStack(alignment: .top, spacing: 10) {
                                Text(String(format: "%02d:00", hour))
                                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    .frame(width: 44, alignment: .trailing)
                                Rectangle().fill(.quaternary).frame(height: 1)
                            }
                            .frame(height: hourHeight, alignment: .top)
                            .id(hour)
                          }
                        }
                        ForEach(layouts) { placement in
                            taskBlock(placement.task)
                                .frame(width: max(1, usable / CGFloat(placement.columns) - 5), height: placement.height)
                                .offset(x: 58 + usable / CGFloat(placement.columns) * CGFloat(placement.column), y: placement.y)
                        }
                        if calendar.isDateInToday(day) {
                            TimelineView(.periodic(from: .now, by: 60)) { tick in
                                let parts = calendar.dateComponents([.hour, .minute], from: tick.date)
                                HStack(spacing: 0) {
                                    Circle().fill(.red).frame(width: 7, height: 7)
                                    Rectangle().fill(.red).frame(height: 1)
                                }
                                .padding(.leading, 51)
                                .offset(y: CGFloat((parts.hour ?? 0) * 60 + (parts.minute ?? 0)) / 60 * hourHeight)
                            }.allowsHitTesting(false)
                        }
                    }
                }
                .frame(height: hourHeight * 24)
                .padding(.top, 12).padding(.trailing, 12)
            }
            .onAppear { proxy.scrollTo(8, anchor: .top) }
            .onChange(of: day) { _, _ in proxy.scrollTo(8, anchor: .top) }
        }
    }

    private func taskBlock(_ task: PlannerTask) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Button {
                task.completed.toggle()
                do { try context.save() } catch { context.rollback(); errorMessage = error.localizedDescription }
            } label: {
                Image(systemName: task.completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.completed ? "Вернуть в работу" : "Завершить задачу")
            Button { draft = TaskDraft(task: task) } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.subheadline.weight(.semibold))
                        .strikethrough(task.completed).lineLimit(2)
                    Text("\(task.start.formatted(date: .omitted, time: .shortened))–\(task.end.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.monospacedDigit()).lineLimit(1)
                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .contentShape(Rectangle())
            }.buttonStyle(.plain)
        }
        .padding(8)
        .foregroundStyle(task.completed ? Color.secondary : Color.indigo)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(task.completed ? Color.secondary.opacity(0.10) : Color.indigo.opacity(0.13), in: RoundedRectangle(cornerRadius: 10))
        .overlay(alignment: .leading) { RoundedRectangle(cornerRadius: 2).fill(task.completed ? Color.gray : .indigo).frame(width: 3).padding(.vertical, 8) }
        .clipped()
    }

    private func shift(_ amount: Int) { day = calendar.date(byAdding: .day, value: amount, to: day)! }
    private func addTask() {
        let hour = calendar.isDateInToday(day) ? min(calendar.component(.hour, from: Date()) + 1, 23) : 9
        draft = TaskDraft(start: calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!)
    }

    private struct Placement: Identifiable {
        var task: PlannerTask
        var column: Int
        var columns: Int
        var y: CGFloat
        var height: CGFloat
        var id: UUID { task.id }
    }
    // Split connected overlap groups into columns, including tasks spanning midnight.
    private func placements() -> [Placement] {
        var result: [Placement] = []
        var group: [PlannerTask] = []
        var groupEnd = day
        func appendGroup() {
            var ends: [Date] = []
            var assigned: [(PlannerTask, Int)] = []
            for task in group {
                let start = max(task.start, day)
                let column = ends.firstIndex(where: { $0 <= start }) ?? ends.count
                if column == ends.count { ends.append(task.end) } else { ends[column] = task.end }
                assigned.append((task, column))
            }
            for (task, column) in assigned {
                let start = max(task.start, day)
                let end = min(task.end, nextDay)
                let parts = calendar.dateComponents([.hour, .minute], from: start)
                let endParts = calendar.dateComponents([.hour, .minute], from: end)
                let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                let endMinute = end == nextDay ? 1440 : (endParts.hour ?? 0) * 60 + (endParts.minute ?? 0)
                result.append(Placement(task: task, column: column, columns: ends.count, y: CGFloat(minute) / 60 * hourHeight, height: max(18, CGFloat(endMinute - minute) / 60 * hourHeight - 3)))
            }
        }
        for task in dayTasks {
            if !group.isEmpty && task.start >= groupEnd { appendGroup(); group = [] }
            group.append(task)
            groupEnd = group.count == 1 ? task.end : max(groupEnd, task.end)
        }
        appendGroup()
        return result
    }
}
