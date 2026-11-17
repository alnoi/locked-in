import Foundation

public struct TaskRecord: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var title: String
  public var description: String?
  public var listID: UUID?
  public var parentID: UUID?
  public var isProject: Bool?
  public var deadlineDate: String?
  public var deadlineAt: Date?
  public var plannedAt: Date?
  public var durationMinutes: Int?
  public var reminderMode: ReminderMode?
  public var reminderMinutesBefore: Int?
  public var completed: Bool
  public var tagIDs: [UUID]
  public var createdAt: Date
  public var updatedAt: Date

  public init(id: UUID = UUID(), input: TaskInput, completed: Bool = false, createdAt: Date = .now)
  {
    self.id = id
    title = input.title
    description = input.description
    listID = input.listID
    parentID = input.parentID
    isProject = input.isProject
    deadlineDate = input.deadlineDate
    deadlineAt = input.deadlineAt
    plannedAt = input.plannedAt
    durationMinutes = input.durationMinutes
    reminderMode = input.reminderMode
    reminderMinutesBefore = input.reminderMinutesBefore
    self.completed = completed
    tagIDs = input.tagIDs
    self.createdAt = createdAt
    updatedAt = .now
  }
  public var plannedEnd: Date? {
    plannedAt.map { $0.addingTimeInterval(Double(durationMinutes ?? 0) * 60) }
  }
}

public struct TaskInput: Codable, Equatable, Sendable {
  public var title: String
  public var description: String?
  public var listID: UUID?
  public var parentID: UUID?
  public var isProject: Bool?
  public var deadlineDate: String?
  public var deadlineAt: Date?
  public var plannedAt: Date?
  public var durationMinutes: Int?
  public var reminderMode: ReminderMode?
  public var reminderMinutesBefore: Int?
  public var tagIDs: [UUID]
  public init(
    title: String = "", description: String? = nil, listID: UUID? = nil, parentID: UUID? = nil,
    deadlineDate: String? = nil, deadlineAt: Date? = nil, plannedAt: Date? = nil,
    durationMinutes: Int? = nil, reminderMode: ReminderMode? = nil,
    reminderMinutesBefore: Int? = nil,
    tagIDs: [UUID] = [], isProject: Bool? = nil
  ) {
    self.title = title
    self.description = description
    self.listID = listID
    self.parentID = parentID
    self.isProject = isProject
    self.deadlineDate = deadlineDate
    self.deadlineAt = deadlineAt
    self.plannedAt = plannedAt
    self.durationMinutes = durationMinutes
    self.reminderMode = reminderMode
    self.reminderMinutesBefore = reminderMinutesBefore
    self.tagIDs = tagIDs
  }
  public init(_ task: TaskRecord) {
    self.init(
      title: task.title, description: task.description, listID: task.listID,
      parentID: task.parentID,
      deadlineDate: task.deadlineDate, deadlineAt: task.deadlineAt, plannedAt: task.plannedAt,
      durationMinutes: task.durationMinutes, reminderMode: task.reminderMode,
      reminderMinutesBefore: task.reminderMinutesBefore, tagIDs: task.tagIDs, isProject: task.isProject)
  }
}

public struct BoardRecord: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var name: String
  public var code: String?
  public var parentID: UUID?
  public var filterCompleted: Bool?
  public var tagIDs: [UUID]
  public var createdAt: Date
  public var updatedAt: Date
  public init(id: UUID = UUID(), input: BoardInput, createdAt: Date = .now, code: String? = nil) {
    self.code = code
    self.id = id
    name = input.name
    parentID = input.parentID
    filterCompleted = input.filterCompleted
    tagIDs = input.tagIDs
    self.createdAt = createdAt
    updatedAt = .now
  }
}
extension BoardRecord { public var isGeneral: Bool { code == "general" } }
public struct BoardInput: Codable, Sendable {
  public var name: String
  public var parentID: UUID?
  public var filterCompleted: Bool?
  public var tagIDs: [UUID]
  public init(
    name: String = "", parentID: UUID? = nil, filterCompleted: Bool? = nil, tagIDs: [UUID] = []
  ) {
    self.name = name
    self.parentID = parentID
    self.filterCompleted = filterCompleted
    self.tagIDs = tagIDs
  }
  public init(_ list: BoardRecord) {
    self.init(
      name: list.name, parentID: list.parentID, filterCompleted: list.filterCompleted,
      tagIDs: list.tagIDs)
  }
}
public struct TaskList: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var name: String
  public var position: Int
  public var boardID: UUID?
  public var createdAt: Date
  public var updatedAt: Date
  public init(id: UUID = UUID(), input: ListInput, createdAt: Date = .now, position: Int = 0) {
    self.position = position
    self.id = id
    name = input.name
    boardID = input.boardID
    self.createdAt = createdAt
    updatedAt = .now
  }
  private enum CodingKeys: String, CodingKey {
    case id, name, boardID, position, createdAt, updatedAt
  }
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    id = try values.decode(UUID.self, forKey: .id)
    name = try values.decode(String.self, forKey: .name)
    boardID = try values.decodeIfPresent(UUID.self, forKey: .boardID)
    position = try values.decodeIfPresent(Int.self, forKey: .position) ?? 0
    createdAt = try values.decode(Date.self, forKey: .createdAt)
    updatedAt = try values.decode(Date.self, forKey: .updatedAt)
  }
}
public struct ListInput: Codable, Sendable {
  public var name: String
  public var boardID: UUID?
  public init(name: String = "", boardID: UUID? = nil) {
    self.name = name
    self.boardID = boardID
  }
  public init(_ list: TaskList) { self.init(name: list.name, boardID: list.boardID) }
}
public struct TagRecord: Codable, Identifiable, Hashable, Sendable {
  public var id: UUID
  public var name: String
  public var color: String?
  public var createdAt: Date
  public var updatedAt: Date
  public init(id: UUID = UUID(), name: String, color: String?, createdAt: Date = .now) {
    self.id = id
    self.name = name
    self.color = color
    self.createdAt = createdAt
    updatedAt = .now
  }
}
public struct CommentRecord: Codable, Identifiable, Sendable {
  public var id: UUID
  public var taskID: UUID
  public var text: String
  public var createdAt: Date
  public var updatedAt: Date
  public init(id: UUID = UUID(), taskID: UUID, text: String, createdAt: Date = .now) {
    self.id = id
    self.taskID = taskID
    self.text = text
    self.createdAt = createdAt
    updatedAt = .now
  }
}
public struct UserRecord: Codable, Sendable {
  public var id: UUID
  public var username: String
  public var timeZone: String
  public var createdAt: Date
  public init(
    id: UUID = UUID(), username: String = "local", timeZone: String = TimeZone.current.identifier
  ) {
    self.id = id
    self.username = username
    self.timeZone = timeZone
    createdAt = .now
  }
}
public struct Snapshot: Codable, Sendable {
  public var user: UserRecord
  public var tasks: [TaskRecord]
  public var boards: [BoardRecord]
  public var lists: [TaskList]
  public var tags: [TagRecord]
  public var comments: [CommentRecord]
  public init(
    user: UserRecord = UserRecord(), tasks: [TaskRecord] = [], boards: [BoardRecord] = [],
    lists: [TaskList] = [],
    tags: [TagRecord] = [], comments: [CommentRecord] = []
  ) {
    self.user = user
    self.tasks = tasks
    self.boards = boards
    self.lists = lists
    self.tags = tags
    self.comments = comments
  }
  public var rootLists: [TaskList] { ListOrdering.sorted(lists) }
  public var generalBoard: BoardRecord? { boards.first(where: \.isGeneral) }
  public var owningBoards: [BoardRecord] { boards.filter { $0.parentID == nil } }
  private enum CodingKeys: String, CodingKey { case user, tasks, boards, lists, tags, comments }
  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    user = try values.decode(UserRecord.self, forKey: .user)
    tasks = try values.decode([TaskRecord].self, forKey: .tasks)
    lists = try values.decode([TaskList].self, forKey: .lists)
    tags = try values.decode([TagRecord].self, forKey: .tags)
    comments = try values.decode([CommentRecord].self, forKey: .comments)
    if let saved = try values.decodeIfPresent([BoardRecord].self, forKey: .boards) {
      boards = saved
    } else {
      let legacy = try values.decode([LegacyList].self, forKey: .lists)
      let general = BoardRecord(
        id: user.id, input: BoardInput(name: "Общая доска"), code: "general")
      boards = [general]
      let filterIDs = Set(legacy.filter { $0.parentID != nil }.map(\.id))
      for old in legacy where old.parentID != nil {
        boards.append(
          BoardRecord(
            id: old.id,
            input: BoardInput(
              name: old.name,
              parentID: old.parentID.flatMap { filterIDs.contains($0) ? $0 : nil } ?? general.id,
              filterCompleted: old.filterCompleted, tagIDs: old.tagIDs ?? []),
            createdAt: old.createdAt))
      }
      lists = lists.filter { !filterIDs.contains($0.id) }.map {
        var value = $0
        value.boardID = general.id
        return value
      }
    }
  }
  private struct LegacyList: Decodable {
    var id: UUID
    var name: String
    var parentID: UUID?
    var filterCompleted: Bool?
    var tagIDs: [UUID]?
    var createdAt: Date
  }

}

public enum Change: Sendable {
  case task(UUID?, TaskInput)
  case completed(UUID, Bool)
  case board(UUID?, BoardInput)
  case list(UUID?, ListInput)
  case tag(UUID?, name: String, color: String)
  case comment(UUID?, taskID: UUID, text: String)
  case deleteTask(UUID)
  case deleteBoard(UUID)
  case deleteList(UUID)
  case deleteTag(UUID)
  case deleteComment(UUID)
}
public enum ResourceKind: Sendable { case task, board, list, tag, comment }
public enum ChangeResult: Sendable {
  case task(TaskRecord)
  case board(BoardRecord)
  case list(TaskList)
  case tag(TagRecord)
  case comment(CommentRecord)
  case deleted(ResourceKind, UUID)
}
public protocol TrackerRepository: Sendable {
  func load() async throws -> Snapshot
  func apply(_ change: Change) async throws -> ChangeResult
}
public struct LegacyTask: Sendable {
  public let id: UUID
  public let input: TaskInput
  public let completed: Bool
  public init(id: UUID, input: TaskInput, completed: Bool) {
    self.id = id
    self.input = input
    self.completed = completed
  }
}
