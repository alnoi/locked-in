import Foundation

public enum TrackerError: LocalizedError, Equatable {
  case validation(String)
  case notFound
  case conflict(String)
  public var errorDescription: String? {
    switch self {
    case .validation(let message), .conflict(let message): return message
    case .notFound: return "Запись больше недоступна. Обнови данные и попробуй снова."
    }
  }
}

public enum TrackerRules {
  public static func validate(_ input: TaskInput, id: UUID?, in snapshot: Snapshot) throws {
    try name(input.title)
    if let offset = input.reminderMinutesBefore, !(0...10080).contains(offset) {
      throw TrackerError.validation("Напоминание можно поставить не раньше чем за неделю.")
    }
    if input.reminderMode == .alarm && input.plannedAt == nil && input.deadlineAt == nil {
      throw TrackerError.validation("Для будильника нужно точное время в календаре или дедлайне.")
    }
    if (input.reminderMode ?? .none) != .none && input.deadlineAt == nil
      && input.deadlineDate == nil && input.plannedAt == nil
    {
      throw TrackerError.validation("Для напоминания укажи дедлайн или время в календаре.")
    }
    if input.deadlineDate != nil && input.deadlineAt != nil {
      throw TrackerError.validation("Выбери один вид дедлайна.")
    }
    if let value = input.deadlineDate, DateOnly.parse(value) == nil {
      throw TrackerError.validation("Некорректная дата дедлайна.")
    }
    if let duration = input.durationMinutes, !(1...525600).contains(duration) {
      throw TrackerError.validation("Длительность должна быть от 1 до 525600 минут.")
    }
    try tags(input.tagIDs, in: snapshot)
    if let listID = input.listID {
      guard let list = snapshot.lists.first(where: { $0.id == listID }) else {
        throw TrackerError.notFound
      }
      _ = list
    }
    if let parentID = input.parentID {
      if parentID == id { throw TrackerError.conflict("Задача не может быть своим родителем.") }
      guard let parent = snapshot.tasks.first(where: { $0.id == parentID }) else {
        throw TrackerError.notFound
      }
      if parent.parentID != nil {
        throw TrackerError.conflict("Допустимы только два уровня: проект и задачи.")
      }
      if let id, snapshot.tasks.contains(where: { $0.parentID == id }) {
        throw TrackerError.conflict("Сначала убери дочерние задачи у этого проекта.")
      }
    }
  }
  public static func validate(_ input: BoardInput, id: UUID?, in snapshot: Snapshot) throws {
    try name(input.name)
    try tags(input.tagIDs, in: snapshot)
    if input.parentID == nil {
      if !input.tagIDs.isEmpty || input.filterCompleted != nil {
        throw TrackerError.validation("Фильтры доступны для дочерних досок.")
      }
      return
    }
    if let id, snapshot.lists.contains(where: { $0.boardID == id }) {
      throw TrackerError.conflict("Доску со списками нельзя превратить в фильтр.")
    }
    var seen = Set<UUID>()
    if let id { seen.insert(id) }
    var next = input.parentID
    while let parentID = next {
      guard seen.insert(parentID).inserted else {
        throw TrackerError.conflict("Доски не могут образовывать цикл.")
      }
      guard let parent = snapshot.boards.first(where: { $0.id == parentID }) else {
        throw TrackerError.notFound
      }
      next = parent.parentID
    }
  }
  public static func validate(_ input: ListInput, id: UUID?, in snapshot: Snapshot) throws {
    try name(input.name)
    guard
      let board = snapshot.boards.first(where: {
        $0.id == (input.boardID ?? snapshot.generalBoard?.id)
      })
    else {
      throw TrackerError.notFound
    }
    if board.parentID != nil {
      throw TrackerError.validation(
        "Создай список в основной доске. Дочерняя доска наследует списки родителя.")
    }
  }
  public static func name(_ name: String) throws {
    if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 300 {
      throw TrackerError.validation("Название должно содержать от 1 до 300 символов.")
    }
  }
  public static func tags(_ ids: [UUID], in snapshot: Snapshot) throws {
    if Set(ids).count != ids.count { throw TrackerError.validation("Теги не должны повторяться.") }
    if ids.contains(where: { id in !snapshot.tags.contains(where: { $0.id == id }) }) {
      throw TrackerError.notFound
    }
  }
  public static func tasks(in listID: UUID, snapshot: Snapshot) -> [TaskRecord] {
    snapshot.tasks.filter { $0.listID == listID }
  }
  public struct Selection: Sendable {
    public var rootID: UUID?
    public var tagIDs: Set<UUID>
    public var completed: Set<Bool>
  }
  public static func selection(for boardID: UUID, snapshot: Snapshot) -> Selection? {
    var id = boardID
    var seen = Set<UUID>()
    var tags = Set<UUID>()
    var completed = Set<Bool>()
    while seen.insert(id).inserted {
      guard let board = snapshot.boards.first(where: { $0.id == id }) else { return nil }
      tags.formUnion(board.tagIDs)
      if let value = board.filterCompleted { completed.insert(value) }
      guard let parentID = board.parentID else {
        return Selection(
          rootID: board.isGeneral ? nil : board.id, tagIDs: tags, completed: completed)
      }
      id = parentID
    }
    return nil
  }
  public static func lists(in boardID: UUID, snapshot: Snapshot) -> [TaskList] {
    guard let selection = selection(for: boardID, snapshot: snapshot) else { return [] }
    return snapshot.rootLists.filter { selection.rootID == nil || $0.boardID == selection.rootID }
  }
  public static func tasks(on boardID: UUID, snapshot: Snapshot) -> [TaskRecord] {
    guard let selection = selection(for: boardID, snapshot: snapshot) else { return [] }
    let listIDs = Set(lists(in: boardID, snapshot: snapshot).map(\.id))
    return snapshot.tasks.filter { task in
      (selection.rootID == nil && task.listID == nil
        || task.listID.map { listIDs.contains($0) } == true)
        && selection.tagIDs.isSubset(of: Set(task.tagIDs))
        && selection.completed.allSatisfy { $0 == task.completed }
    }
  }
  public static func overlaps(_ task: TaskRecord, from: Date, to: Date) -> Bool {
    guard let start = task.plannedAt else { return false }
    if let duration = task.durationMinutes {
      return start < to && start.addingTimeInterval(Double(duration) * 60) > from
    }
    return start >= from && start < to
  }
}

public enum DateOnly {
  public static func string(_ date: Date) -> String { formatter().string(from: date) }
  public static func parse(_ value: String) -> Date? {
    let formatter = formatter()
    guard let date = formatter.date(from: value), formatter.string(from: date) == value else {
      return nil
    }
    return date
  }
  private static func formatter() -> DateFormatter {
    let value = DateFormatter()
    value.calendar = Calendar(identifier: .gregorian)
    value.locale = Locale(identifier: "en_US_POSIX")
    value.timeZone = .current
    value.dateFormat = "yyyy-MM-dd"
    value.isLenient = false
    return value
  }
}
