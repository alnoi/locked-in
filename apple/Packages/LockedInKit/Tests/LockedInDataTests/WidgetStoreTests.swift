import Foundation
import LockedInDomain
import XCTest
@testable import LockedInData

final class WidgetStoreTests: XCTestCase {
  private func folder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    addTeardownBlock { try? FileManager.default.removeItem(at: url) }
    return url
  }
  func testCompletionSurvivesReopeningAndCannotModifyAnotherSpace() throws {
    let directory = try folder()
    let store = WidgetStore(directory: directory)
    let task = TaskRecord(input: TaskInput(title: "Task"))
    let value = WidgetSnapshot(snapshot: Snapshot(tasks: [task]), settings: ConnectionSettings(mode: .local))
    XCTAssertTrue(try store.publish(value))
    XCTAssertFalse(try store.publish(value))
    let command = try store.enqueueCompletion(taskID: task.id, sourceKey: value.sourceKey)
    let reopened = WidgetStore(directory: directory)
    XCTAssertEqual(try reopened.displaySnapshot()?.tasks.first?.completed, true)
    XCTAssertEqual(try reopened.context()?.tasks.first?.completed, false)
    XCTAssertEqual(try reopened.commands(sourceKey: value.sourceKey).map(\.id), [command.id])
    XCTAssertThrowsError(try store.enqueueCompletion(taskID: task.id, sourceKey: "wrong-user"))
    let other = WidgetSnapshot(snapshot: Snapshot(tasks: [task]), settings: ConnectionSettings(mode: .server, serverAddress: "https://other.example"))
    try store.publish(other)
    XCTAssertEqual(try store.displaySnapshot()?.tasks.first?.completed, false)
    XCTAssertTrue(try store.commands(sourceKey: other.sourceKey).isEmpty)
  }
  func testRemoteRefreshPreservesPendingLocalEditsAndHonorsRemoteDeletions() throws {
    let store = WidgetStore(directory: try folder())
    let pending = TaskRecord(input: TaskInput(title: "Local edit"))
    let deleted = TaskRecord(input: TaskInput(title: "Deleted remotely"))
    let snapshot = Snapshot(tasks: [pending, deleted])
    let value = WidgetSnapshot(snapshot: snapshot, settings: ConnectionSettings(mode: .server), pendingTaskIDs: [pending.id], updatedAt: Date(timeIntervalSince1970: 100))
    try store.publish(value)
    var remote = value
    remote.tasks = [TaskRecord(id: pending.id, input: TaskInput(title: "Old server title"))]
    remote.updatedAt = Date(timeIntervalSince1970: 200)
    try store.saveRemote(remote)
    XCTAssertEqual(try store.displaySnapshot()?.tasks.map(\.title), ["Local edit"])
  }
  func testAcknowledgedCompletionDoesNotHideLaterReopenedTask() throws {
    let store = WidgetStore(directory: try folder())
    var task = TaskRecord(input: TaskInput(title: "Task"))
    task.updatedAt = Date(timeIntervalSince1970: 100)
    var value = WidgetSnapshot(snapshot: Snapshot(tasks: [task]), settings: ConnectionSettings(mode: .local))
    try store.publish(value)
    var command = try store.enqueueCompletion(taskID: task.id, sourceKey: value.sourceKey)
    var ack = task; ack.completed = true; ack.updatedAt = Date(timeIntervalSince1970: 200)
    command.acknowledgedTask = ack
    try store.update(command)
    value.tasks[0].updatedAt = Date(timeIntervalSince1970: 300)
    try store.publish(value)
    XCTAssertEqual(try store.displaySnapshot()?.tasks.first?.completed, false)
    try store.remove(command)
    XCTAssertTrue(try store.commands(sourceKey: value.sourceKey).isEmpty)
  }
  func testWidgetDoesNotCompleteTaskForDifferentServerUser() async throws {
    let store = WidgetStore(directory: try folder())
    let task = TaskRecord(input: TaskInput(title: "Task"))
    let value = WidgetSnapshot(snapshot: Snapshot(tasks: [task]), settings: ConnectionSettings(mode: .server))
    try store.publish(value)
    let otherUser = WidgetRemote(snapshot: Snapshot(tasks: [task]))
    try await WidgetService.complete(taskID: task.id, sourceKey: value.sourceKey, store: store, client: otherUser)
    let server = try await otherUser.load()
    XCTAssertEqual(server.tasks.first?.completed, false)
    XCTAssertNil(try store.commands(sourceKey: value.sourceKey).first?.acknowledgedTask)
  }
  func testServiceQueuesOfflineCompletionAndSynchronizesOnlineWithoutOpeningApp() async throws {
    let store = WidgetStore(directory: try folder())
    let task = TaskRecord(input: TaskInput(title: "Task"))
    let snapshot = Snapshot(tasks: [task])
    let value = WidgetSnapshot(snapshot: snapshot, settings: ConnectionSettings(mode: .server))
    try store.publish(value)
    let remote = WidgetRemote(snapshot: snapshot)
    await remote.setOffline(true)
    try await WidgetService.complete(taskID: task.id, sourceKey: value.sourceKey, store: store, client: remote)
    XCTAssertEqual(try store.displaySnapshot()?.tasks.first?.completed, true)
    XCTAssertNil(try store.commands(sourceKey: value.sourceKey).first?.acknowledgedTask)
    await remote.setOffline(false)
    try await WidgetService.complete(taskID: task.id, sourceKey: value.sourceKey, store: store, client: remote)
    let server = try await remote.load()
    XCTAssertEqual(server.tasks.first?.completed, true)
    XCTAssertNotNil(try store.commands(sourceKey: value.sourceKey).last?.acknowledgedTask)
  }
}
private actor WidgetRemote: TaskSyncRemote {
  var snapshot: Snapshot
  var offline = false
  init(snapshot: Snapshot) { self.snapshot = snapshot }
  func setOffline(_ value: Bool) { offline = value }
  func load() throws -> Snapshot {
    if offline { throw URLError(.notConnectedToInternet) }
    return snapshot
  }
  func createTask(id: UUID, input: TaskInput) throws -> TaskRecord { throw TrackerError.notFound }
  func apply(_ change: Change) throws -> ChangeResult {
    if offline { throw URLError(.notConnectedToInternet) }
    guard case .completed(let id, let completed) = change,
      let index = snapshot.tasks.firstIndex(where: { $0.id == id }) else { throw TrackerError.notFound }
    snapshot.tasks[index].completed = completed
    snapshot.tasks[index].updatedAt = .now
    return .task(snapshot.tasks[index])
  }
}
