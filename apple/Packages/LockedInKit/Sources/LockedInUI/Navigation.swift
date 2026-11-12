import Foundation
import LockedInDomain

public enum Destination: Hashable {
    case today, inbox, all, calendar, board, completed, tags
    case boardDetail(UUID)
    case list(UUID)
    case tag(UUID)
    func title(in snapshot: Snapshot) -> String {
        switch self {
        case .today: return "Сегодня"
        case .inbox: return "Входящие"
        case .all: return "Все задачи"
        case .calendar: return "Календарь"
        case .board: return "Общая доска"
        case .completed: return "Завершённые"
        case .tags: return "Теги"
        case .boardDetail(let id): return snapshot.boards.first { $0.id == id }?.name ?? "Доска"
        case .list(let id): return snapshot.lists.first { $0.id == id }?.name ?? "Список"
        case .tag(let id): return "#" + (snapshot.tags.first { $0.id == id }?.name ?? "Тег")
        }
    }
    var symbol: String {
        switch self {
        case .today: return "sun.max"
        case .inbox: return "tray"
        case .all: return "checklist"
        case .calendar: return "calendar"
        case .board, .boardDetail: return "rectangle.split.3x1"
        case .completed: return "checkmark.circle"
        case .tags, .tag: return "number"
        case .list: return "list.bullet"
        }
    }
    func tasks(in snapshot: Snapshot, now: Date = .now) -> [TaskRecord] {
        switch self {
        case .inbox: return snapshot.tasks.filter { $0.listID == nil }
        case .completed: return snapshot.tasks.filter(\.completed)
        case .list(let id): return TrackerRules.tasks(in: id, snapshot: snapshot)
        case .tag(let id): return snapshot.tasks.filter { $0.tagIDs.contains(id) }
        case .today:
            return snapshot.tasks.filter { task in
                if task.completed { return false }
                if let date = task.plannedAt, Calendar.current.isDate(date, inSameDayAs: now) { return true }
                if let date = task.deadlineAt,
                    date < Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!
                {
                    return true
                }
                if let date = task.deadlineDate, date <= DateOnly.string(now) { return true }
                return false
            }
        default: return snapshot.tasks
        }
    }
}
struct TaskPresentation: Identifiable {
    let id = UUID()
    var taskID: UUID?
    var input = TaskInput()
}
struct ListPresentation: Identifiable {
    let id = UUID()
    var listID: UUID?
    var input = ListInput()
}

struct BoardPresentation: Identifiable {
    let id = UUID()
    var boardID: UUID?
    var input = BoardInput()
}
