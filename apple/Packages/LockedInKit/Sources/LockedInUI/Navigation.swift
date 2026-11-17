import Foundation
import LockedInDomain

public enum Destination: Hashable {
    case today, inbox, all, calendar, board, overdue, completed, tags
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
        case .overdue: return "Просроченные"
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
        case .overdue: return "calendar.badge.exclamationmark"
        case .completed: return "checkmark.circle"
        case .tags, .tag: return "number"
        case .list: return "list.bullet"
        }
    }
    func tasks(in snapshot: Snapshot, now: Date = .now) -> [TaskRecord] {
        switch self {
        case .inbox: return snapshot.tasks.filter { TaskProjectGrouping.listID(of: $0, in: snapshot.tasks) == nil }
        case .completed: return snapshot.tasks.filter(\.completed)
        case .list(let id): return TrackerRules.tasks(in: id, snapshot: snapshot)
        case .tag(let id): return snapshot.tasks.filter { $0.tagIDs.contains(id) }
        case .overdue:
            return snapshot.tasks.filter { WidgetAgenda.needsRescheduling($0, now: now) }
        case .today:
            return WidgetAgenda.today(snapshot.tasks, now: now)
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
