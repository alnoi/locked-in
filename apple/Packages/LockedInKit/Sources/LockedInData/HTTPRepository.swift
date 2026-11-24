import Foundation
import LockedInDomain

public struct HTTPRepository: TaskSyncRemote {
  public let baseURL: URL
  private let session: URLSession
  public init(baseURL: URL, session: URLSession = .shared) {
    self.baseURL = baseURL
    self.session = session
  }
  private struct Collection<Value: Decodable>: Decodable {
    let items: [Value]
    let total: Int
  }
  public func load() async throws -> Snapshot {
    async let user: UserRecord = request("me")
    async let tasks: Collection<TaskRecord> = request("tasks")
    async let boards: Collection<BoardRecord> = request("boards")
    async let lists: Collection<TaskList> = request("lists")
    async let tags: Collection<TagRecord> = request("tags")
    async let comments: Collection<CommentRecord> = request("comments")
    return try await Snapshot(
      user: user, tasks: tasks.items, boards: boards.items, lists: lists.items, tags: tags.items,
      comments: comments.items)
  }
  public func createTask(id: UUID, input: TaskInput) async throws -> TaskRecord {
    var body = try object(input)
    body["id"] = id.uuidString
    return try await request("tasks", method: "POST", body: body)
  }
  public func apply(_ change: Change) async throws -> ChangeResult {
    switch change {
    case .restore(let record):
      switch record {
      case .task(let value): return .task(try await request("tasks/\(value.id.uuidString)/restore", method: "POST"))
      case .board(let value): return .board(try await request("boards/\(value.id.uuidString)/restore", method: "POST"))
      case .list(let value): return .list(try await request("lists/\(value.id.uuidString)/restore", method: "POST"))
      case .tag(let value): return .tag(try await request("tags/\(value.id.uuidString)/restore", method: "POST"))
      case .comment(let value): return .comment(try await request("comments/\(value.id.uuidString)/restore", method: "POST"))
      case .deleted: throw TrackerError.validation("Невозможно восстановить удаление без записи.")
      }
    case .task(let id, let input):
      var body = try object(input)
      if id != nil {
        for key in [
          "description", "listID", "parentID", "deadlineDate", "deadlineAt", "plannedAt",
          "durationMinutes",
        ] where body[key] == nil {
          body["clear" + key.prefix(1).uppercased() + key.dropFirst()] = true
        }
      }
      return .task(
        try await request(path("tasks", id), method: id == nil ? "POST" : "PATCH", body: body))
    case .completed(let id, let completed):
      return .task(
        try await request(
          "tasks/\(id.uuidString)/\(completed ? "complete" : "reopen")", method: "POST"))
    case .board(let id, let input):
      var body = try object(input)
      if id != nil {
        if input.parentID == nil { body["clearParentID"] = true }
        if input.filterCompleted == nil { body["clearFilterCompleted"] = true }
      }
      return .board(
        try await request(path("boards", id), method: id == nil ? "POST" : "PATCH", body: body))
    case .list(let id, let input):
      return .list(
        try await request(
          path("lists", id), method: id == nil ? "POST" : "PATCH", body: try object(input)))
    case .tag(let id, let name, let color):
      return .tag(
        try await request(
          path("tags", id), method: id == nil ? "POST" : "PATCH",
          body: ["name": name, "color": color]))
    case .comment(let id, let taskID, let text):
      var body: [String: Any] = ["text": text]
      if id == nil { body["taskID"] = taskID.uuidString }
      return .comment(
        try await request(path("comments", id), method: id == nil ? "POST" : "PATCH", body: body))
    case .deleteTask(let id):
      try await remove("tasks", id)
      return .deleted(.task, id)
    case .deleteBoard(let id):
      try await remove("boards", id)
      return .deleted(.board, id)
    case .deleteList(let id):
      try await remove("lists", id)
      return .deleted(.list, id)
    case .deleteTag(let id):
      try await remove("tags", id)
      return .deleted(.tag, id)
    case .deleteComment(let id):
      try await remove("comments", id)
      return .deleted(.comment, id)
    }
  }
  private func path(_ resource: String, _ id: UUID?) -> String {
    id.map { resource + "/" + $0.uuidString } ?? resource
  }
  private func object<T: Encodable>(_ value: T) throws -> [String: Any] {
    try JSONSerialization.jsonObject(with: JSONCodec.encoder().encode(value)) as! [String: Any]
  }
  private func request<T: Decodable>(
    _ path: String, method: String = "GET", body: [String: Any]? = nil
  ) async throws
    -> T
  {
    let data = try await send(path, method: method, body: body)
    return try JSONCodec.decoder().decode(T.self, from: data)
  }
  private func remove(_ resource: String, _ id: UUID) async throws {
    _ = try await send(path(resource, id), method: "DELETE")
  }
  private func send(_ path: String, method: String, body: [String: Any]? = nil) async throws -> Data
  {
    var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/" + path))
    request.httpMethod = method
    request.timeoutInterval = 12
    if let body {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    switch response.statusCode {
    case 200..<300: return data
    case 400: throw TrackerError.validation("Проверь поля: даты, длительность и связи задачи.")
    case 401, 403: throw TrackerError.validation("Нет доступа к этому серверу.")
    case 404: throw TrackerError.notFound
    case 409:
      throw TrackerError.conflict(
        "Есть связанные задачи, списки или теги. Сначала перенеси их или убери связь.")
    case 500...599: throw SyncConnectionError.serverUnavailable
    default: throw TrackerError.validation("Сервер отклонил запрос. Попробуй ещё раз.")
    }
  }
}
