import Foundation
import SwiftData
import LockedInDomain

@Model
final class PlannerTask {
    var id: UUID
    var title: String
    var start: Date
    var duration: Int
    var completed: Bool
    init(title: String, start: Date, duration: Int) {
        id = UUID(); self.title = title; self.start = start; self.duration = duration; completed = false
    }
}
@MainActor enum LegacyStore {
    static func read() throws -> [LegacyTask] {
        let container = try ModelContainer(for: PlannerTask.self)
        return try container.mainContext.fetch(FetchDescriptor<PlannerTask>()).map {
            LegacyTask(id: $0.id, input: TaskInput(title: $0.title, plannedAt: $0.start, durationMinutes: max(1, $0.duration)), completed: $0.completed)
        }
    }
}
