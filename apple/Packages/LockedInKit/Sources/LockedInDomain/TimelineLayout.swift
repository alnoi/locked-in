import Foundation

public struct TimelinePlacement: Identifiable, Sendable {
    public var task: TaskRecord
    public var column: Int
    public var columns: Int
    public var startMinute: Double
    public var durationMinutes: Double
    public var id: UUID { task.id }
}
public enum TimelineLayout {
    public static func placements(tasks: [TaskRecord], day: Date, calendar: Calendar = .current) -> [TimelinePlacement] {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return [] }
        let visible = tasks.filter { TrackerRules.overlaps($0, from: start, to: end) }.sorted {
            if $0.plannedAt == $1.plannedAt { return $0.id.uuidString < $1.id.uuidString }
            return $0.plannedAt! < $1.plannedAt!
        }
        struct Span { var task: TaskRecord; var start: Double; var end: Double }
        let spans = visible.map { task -> Span in
            let actualStart = max(start, task.plannedAt!)
            let actualEnd = min(end, task.plannedEnd ?? actualStart)
            let parts = calendar.dateComponents([.hour, .minute], from: actualStart)
            let endParts = calendar.dateComponents([.hour, .minute], from: actualEnd)
            let minute = Double((parts.hour ?? 0) * 60 + (parts.minute ?? 0))
            let endMinute = actualEnd == end ? 1440 : Double((endParts.hour ?? 0) * 60 + (endParts.minute ?? 0))
            return Span(task: task, start: minute, end: min(1440, max(minute + 1, endMinute)))
        }
        var result: [TimelinePlacement] = []
        var group: [Span] = []
        var groupEnd = 0.0
        func appendGroup() {
            var ends: [Double] = []
            var items: [(Span, Int)] = []
            for span in group {
                let column = ends.firstIndex { $0 <= span.start } ?? ends.count
                if column == ends.count { ends.append(span.end) } else { ends[column] = span.end }
                items.append((span, column))
            }
            for (span, column) in items { result.append(TimelinePlacement(task: span.task, column: column, columns: ends.count, startMinute: span.start, durationMinutes: span.end - span.start)) }
        }
        for span in spans {
            if !group.isEmpty && span.start >= groupEnd { appendGroup(); group = [] }
            group.append(span); groupEnd = max(groupEnd, span.end)
        }
        appendGroup()
        return result
    }
}
