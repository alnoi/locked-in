import Foundation

public struct TaskOrder: Codable, Sendable, Equatable {
  public var taskIDs: [UUID]
  public var revision: Int64
  public init(taskIDs: [UUID] = [], revision: Int64 = 0) {
    self.taskIDs = taskIDs; self.revision = revision
  }
}
public protocol TaskOrderRepository: Sendable {
  func saveTaskOrder(_ ids: [UUID], initializeOnly: Bool) async throws -> TaskOrder
}
