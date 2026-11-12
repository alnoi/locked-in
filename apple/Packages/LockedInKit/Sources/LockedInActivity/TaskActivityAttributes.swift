#if os(iOS)
  import ActivityKit
  import Foundation

  public struct TaskActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
      public var title: String
      public var eventDate: Date
      public var tagNames: [String]
      public var colorHex: String
      public init(title: String, eventDate: Date, tagNames: [String], colorHex: String) {
        self.title = title
        self.eventDate = eventDate
        self.tagNames = tagNames
        self.colorHex = colorHex
      }
    }
    public var taskID: UUID
    public var space: String
    public init(taskID: UUID, space: String) {
      self.taskID = taskID
      self.space = space
    }
  }
#endif
