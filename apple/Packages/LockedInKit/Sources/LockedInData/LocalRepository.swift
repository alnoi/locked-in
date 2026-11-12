import Foundation
import LockedInDomain

public actor LocalRepository: TrackerRepository {
  private struct Archive: Codable {
    init() {}
    private enum CodingKeys: String, CodingKey {
      case snapshot, deletedTasks, deletedBoards, deletedLists, deletedTags, deletedComments
    }
    init(from decoder: Decoder) throws {
      let values = try decoder.container(keyedBy: CodingKeys.self)
      snapshot = try values.decode(Snapshot.self, forKey: .snapshot)
      deletedTasks = try values.decodeIfPresent([TaskRecord].self, forKey: .deletedTasks) ?? []
      deletedBoards = try values.decodeIfPresent([BoardRecord].self, forKey: .deletedBoards) ?? []
      deletedLists = try values.decodeIfPresent([TaskList].self, forKey: .deletedLists) ?? []
      deletedTags = try values.decodeIfPresent([TagRecord].self, forKey: .deletedTags) ?? []
      deletedComments =
        try values.decodeIfPresent([CommentRecord].self, forKey: .deletedComments) ?? []
    }
    var snapshot = Snapshot()
    var deletedTasks: [TaskRecord] = []
    var deletedBoards: [BoardRecord] = []
    var deletedLists: [TaskList] = []
    var deletedTags: [TagRecord] = []
    var deletedComments: [CommentRecord] = []
  }
  private let file: URL
  private var archive: Archive?
  public init(file: URL) { self.file = file }
  public func load() throws -> Snapshot {
    if let archive { return archive.snapshot }
    let value: Archive
    if FileManager.default.fileExists(atPath: file.path) {
      let data = try Data(contentsOf: file)
      value = try JSONCodec.decoder().decode(Archive.self, from: data)
      if let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
        let snapshot = root["snapshot"] as? [String: Any], snapshot["boards"] == nil
      {
        let backup = file.appendingPathExtension("before_boards")
        if !FileManager.default.fileExists(atPath: backup.path) {
          try data.write(to: backup, options: .withoutOverwriting)
        }
        try persist(value)
      }
    } else {
      var created = Archive()
      created.snapshot.boards = [
        BoardRecord(input: BoardInput(name: "Общая доска"), code: "general")
      ]
      value = created
      try persist(value)
    }
    archive = value
    return value.snapshot
  }
  public func apply(_ change: Change) throws -> ChangeResult {
    let snapshot = try load()
    var next = archive!
    let result: ChangeResult
    switch change {
    case .task(let id, let input):
      try TrackerRules.validate(input, id: id, in: snapshot)
      let existing = snapshot.tasks.first { $0.id == id }
      if id != nil && existing == nil { throw TrackerError.notFound }
      result = .task(
        TaskRecord(
          id: id ?? UUID(), input: input, completed: existing?.completed ?? false,
          createdAt: existing?.createdAt ?? .now))
    case .completed(let id, let completed):
      guard var task = snapshot.tasks.first(where: { $0.id == id }) else {
        throw TrackerError.notFound
      }
      task.completed = completed
      task.updatedAt = .now
      result = .task(task)
    case .board(let id, let input):
      try TrackerRules.validate(input, id: id, in: snapshot)
      let existing = snapshot.boards.first { $0.id == id }
      if id != nil && existing == nil { throw TrackerError.notFound }
      if existing?.isGeneral == true
        && (input.parentID != nil || !input.tagIDs.isEmpty || input.filterCompleted != nil)
      {
        throw TrackerError.validation("Общая доска не может быть дочерней или иметь фильтр.")
      }
      result = .board(
        BoardRecord(
          id: id ?? UUID(), input: input, createdAt: existing?.createdAt ?? .now,
          code: existing?.code))
    case .list(let id, var input):
      if input.boardID == nil { input.boardID = snapshot.generalBoard?.id }
      try TrackerRules.validate(input, id: id, in: snapshot)
      let existing = snapshot.lists.first { $0.id == id }
      if id != nil && existing == nil { throw TrackerError.notFound }
      result = .list(
        TaskList(
          id: id ?? UUID(), input: input, createdAt: existing?.createdAt ?? .now,
          position: existing?.position ?? ((snapshot.lists.map(\.position).max() ?? -1) + 1)))
    case .tag(let id, let name, let color):
      try TrackerRules.name(name)
      if color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) == nil {
        throw TrackerError.validation("Выбери цвет тега.")
      }
      let existing = snapshot.tags.first { $0.id == id }
      if id != nil && existing == nil { throw TrackerError.notFound }
      result = .tag(
        TagRecord(
          id: id ?? UUID(), name: name, color: color, createdAt: existing?.createdAt ?? .now))
    case .comment(let id, let taskID, let text):
      guard snapshot.tasks.contains(where: { $0.id == taskID }) else { throw TrackerError.notFound }
      if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || text.count > 20000 {
        throw TrackerError.validation("Комментарий должен содержать от 1 до 20000 символов.")
      }
      let existing = snapshot.comments.first { $0.id == id }
      if id != nil && existing == nil { throw TrackerError.notFound }
      result = .comment(
        CommentRecord(
          id: id ?? UUID(), taskID: taskID, text: text, createdAt: existing?.createdAt ?? .now))
    case .deleteTask(let id):
      guard let task = snapshot.tasks.first(where: { $0.id == id }) else {
        throw TrackerError.notFound
      }
      if snapshot.tasks.contains(where: { $0.parentID == id }) {
        throw TrackerError.conflict("Сначала перенеси или удали дочерние задачи.")
      }
      next.deletedTasks.append(task)
      next.deletedComments.append(contentsOf: snapshot.comments.filter { $0.taskID == id })
      result = .deleted(.task, id)
    case .deleteBoard(let id):
      guard let board = snapshot.boards.first(where: { $0.id == id }) else {
        throw TrackerError.notFound
      }
      if board.isGeneral || snapshot.boards.contains(where: { $0.parentID == id })
        || snapshot.lists.contains(where: { $0.boardID == id })
      {
        throw TrackerError.conflict(
          "Общую доску, доску со списками или дочерними досками удалить нельзя.")
      }
      next.deletedBoards.append(board)
      result = .deleted(.board, id)
    case .deleteList(let id):
      guard let list = snapshot.lists.first(where: { $0.id == id }) else {
        throw TrackerError.notFound
      }
      if snapshot.tasks.contains(where: { $0.listID == id }) {
        throw TrackerError.conflict("Сначала перенеси задачи в другой список.")
      }
      next.deletedLists.append(list)
      result = .deleted(.list, id)
    case .deleteTag(let id):
      guard let tag = snapshot.tags.first(where: { $0.id == id }) else {
        throw TrackerError.notFound
      }
      if snapshot.tasks.contains(where: { $0.tagIDs.contains(id) })
        || snapshot.boards.contains(where: { $0.tagIDs.contains(id) })
      {
        throw TrackerError.conflict("Сначала убери тег из задач и фильтров списков.")
      }
      next.deletedTags.append(tag)
      result = .deleted(.tag, id)
    case .deleteComment(let id):
      guard let comment = snapshot.comments.first(where: { $0.id == id }) else {
        throw TrackerError.notFound
      }
      next.deletedComments.append(comment)
      result = .deleted(.comment, id)
    }
    next.snapshot.receive(result)
    try persist(next)
    archive = next
    return result
  }
  private func persist(_ archive: Archive) throws {
    try FileManager.default.createDirectory(
      at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
    try JSONCodec.encoder().encode(archive).write(to: file, options: .atomic)
  }
}
