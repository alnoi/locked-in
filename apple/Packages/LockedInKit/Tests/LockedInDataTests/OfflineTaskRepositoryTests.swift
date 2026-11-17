import Foundation
import LockedInDomain
import XCTest
@testable import LockedInData

final class OfflineTaskRepositoryTests: XCTestCase {
  func testServerOnlyActionsExplainConnectionRequirementWithoutChangingLocalData() async throws {
    for initiallyOffline in [true, false] {
      let fixture = try SyncFixture()
      defer { fixture.remove() }
      let repository = fixture.repository()
      await fixture.remote.setOffline(initiallyOffline)
      _ = try await repository.load()
      guard case .task(let task) = try await repository.apply(.task(nil, TaskInput(title: "Keep offline task"))) else { return XCTFail() }
      await fixture.remote.setOffline(true)
      let actions: [Change] = [
        .list(nil, ListInput(name: "Needs connection")),
        .board(nil, BoardInput(name: "Needs connection")),
        .tag(nil, name: "Needs connection", color: "#777777"),
        .comment(nil, taskID: task.id, text: "Needs connection"),
      ]
      for action in actions {
        do {
          _ = try await repository.apply(action)
          XCTFail("Server-only change unexpectedly succeeded")
        } catch SyncConnectionError.connectionRequired {
          XCTAssertTrue(SyncConnectionError.connectionRequired.localizedDescription.contains("нужна связь с сервером"))
        } catch { XCTFail("Unexpected error: \(error)") }
      }
      let status = await repository.status()
      XCTAssertTrue(status.isOffline)
      XCTAssertEqual(status.pendingTaskIDs, [task.id])
      let reopened = try await fixture.repository().load()
      XCTAssertEqual(reopened.tasks.map(\.id), [task.id])
      XCTAssertTrue(reopened.lists.isEmpty)
      XCTAssertTrue(reopened.boards.isEmpty)
      XCTAssertTrue(reopened.tags.isEmpty)
      XCTAssertTrue(reopened.comments.isEmpty)
    }
  }

  func testOfflineCreateEditCompleteSurviveRestartAndSyncWithStableID() async throws {
    let fixture = try SyncFixture()
    defer { fixture.remove() }
    let first = fixture.repository()
    _ = try await first.load()
    guard case .task(let created) = try await first.apply(.task(nil, TaskInput(title: "Draft"))) else { return XCTFail() }
    var input = TaskInput(created); input.title = "Saved offline"; input.durationMinutes = 45
    _ = try await first.apply(.task(created.id, input))
    _ = try await first.apply(.completed(created.id, true))
    let reopened = fixture.repository()
    let restored = try await reopened.load()
    XCTAssertEqual(restored.tasks.first?.id, created.id)
    XCTAssertEqual(restored.tasks.first?.title, "Saved offline")
    XCTAssertEqual(restored.tasks.first?.completed, true)
    let before = await reopened.status()
    XCTAssertEqual(before.pendingTaskIDs, [created.id])
    await fixture.remote.setOffline(false)
    let synced = try await reopened.load()
    XCTAssertEqual(synced.tasks.count, 1)
    XCTAssertEqual(synced.tasks.first?.id, created.id)
    XCTAssertEqual(synced.tasks.first?.durationMinutes, 45)
    XCTAssertEqual(synced.tasks.first?.completed, true)
    let after = await reopened.status()
    XCTAssertTrue(after.pendingTaskIDs.isEmpty)
    let restarted = try await fixture.repository().load()
    XCTAssertEqual(restarted.tasks.map(\.id), [created.id])
  }
  func testLostCreateResponseDoesNotDuplicateAndPendingDeleteCleansItUp() async throws {
    let fixture = try SyncFixture()
    defer { fixture.remove() }
    let repository = fixture.repository()
    _ = try await repository.load()
    guard case .task(let task) = try await repository.apply(.task(nil, TaskInput(title: "Retry"))) else { return XCTFail() }
    await fixture.remote.setOffline(false)
    await fixture.remote.loseNextCreateResponse()
    _ = try await repository.load()
    let pending = await repository.status()
    XCTAssertEqual(pending.pendingTaskIDs, [task.id])
    _ = try await repository.load()
    let server = try await fixture.remote.load()
    XCTAssertEqual(server.tasks.map(\.id), [task.id])
    let status = await repository.status()
    XCTAssertTrue(status.pendingTaskIDs.isEmpty)
    await fixture.remote.setOffline(true)
    _ = try await repository.apply(.deleteTask(task.id))
    let offline = try await repository.load()
    XCTAssertTrue(offline.tasks.isEmpty)
    await fixture.remote.setOffline(false)
    _ = try await repository.load()
    let deleted = try await fixture.remote.load()
    XCTAssertTrue(deleted.tasks.isEmpty)
  }
  func testSyncPreservesUnrelatedServerEditsAndRejectedChangesRemainPending() async throws {
    let task = TaskRecord(input: TaskInput(title: "Initial", description: "Old"))
    let fixture = try SyncFixture(tasks: [task])
    defer { fixture.remove() }
    let repository = fixture.repository()
    _ = try await repository.load()
    var local = TaskInput(task); local.title = "Offline title"
    _ = try await repository.apply(.task(task.id, local))
    var remote = TaskInput(task); remote.description = "Changed on another device"; remote.durationMinutes = 90
    await fixture.remote.setOffline(false)
    _ = try await fixture.remote.apply(.task(task.id, remote))
    _ = try await fixture.remote.apply(.completed(task.id, true))
    await fixture.remote.rejectPatches(true)
    let rejected = try await repository.load()
    XCTAssertEqual(rejected.tasks.first?.title, "Offline title")
    let blocked = await repository.status()
    XCTAssertNotNil(blocked.issue)
    XCTAssertEqual(blocked.pendingTaskIDs, [task.id])
    await fixture.remote.rejectPatches(false)
    let result = try await repository.load()
    XCTAssertEqual(result.tasks.first?.title, "Offline title")
    XCTAssertEqual(result.tasks.first?.description, "Changed on another device")
    XCTAssertEqual(result.tasks.first?.durationMinutes, 90)
    XCTAssertEqual(result.tasks.first?.completed, true)
  }
  func testEditingWhileSyncingDoesNotAcknowledgeTheNewerVersion() async throws {
    let task = TaskRecord(input: TaskInput(title: "Initial"))
    let fixture = try SyncFixture(tasks: [task])
    defer { fixture.remove() }
    let repository = fixture.repository()
    _ = try await repository.load()
    _ = try await repository.apply(.task(task.id, TaskInput(title: "First")))
    await fixture.remote.setOffline(false)
    await fixture.remote.pauseNextPatch()
    let sync = Task { try await repository.load() }
    await fixture.remote.waitForPatch()
    _ = try await repository.apply(.task(task.id, TaskInput(title: "Second")))
    await fixture.remote.releasePatch()
    _ = try await sync.value
    let pending = await repository.status()
    XCTAssertEqual(pending.pendingTaskIDs, [task.id])
    let result = try await repository.load()
    XCTAssertEqual(result.tasks.first?.title, "Second")
    let final = await repository.status()
    XCTAssertTrue(final.pendingTaskIDs.isEmpty)
  }
  func testOfflineProjectAndChildAreCreatedInDependencyOrder() async throws {
    let fixture = try SyncFixture()
    defer { fixture.remove() }
    let repository = fixture.repository()
    _ = try await repository.load()
    guard case .task(let parent) = try await repository.apply(.task(nil, TaskInput(title: "Project"))) else { return XCTFail() }
    guard case .task(let child) = try await repository.apply(.task(nil, TaskInput(title: "Child", parentID: parent.id))) else { return XCTFail() }
    await fixture.remote.setOffline(false)
    let result = try await repository.load()
    XCTAssertEqual(result.tasks.count, 2)
    XCTAssertEqual(result.tasks.first(where: { $0.id == child.id })?.parentID, parent.id)
    let status = await repository.status()
    XCTAssertTrue(status.pendingTaskIDs.isEmpty)
  }
}

private struct SyncFixture {
  let directory: URL
  let remote: SyncTestRemote
  init(tasks: [TaskRecord] = []) throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let snapshot = Snapshot(tasks: tasks)
    remote = SyncTestRemote(snapshot: snapshot)
    try JSONCodec.encoder().encode(snapshot).write(to: directory.appendingPathComponent("seed.json"))
  }
  func repository() -> OfflineTaskRepository {
    OfflineTaskRepository(remote: remote, file: directory.appendingPathComponent("queue.json"), seedFile: directory.appendingPathComponent("seed.json"))
  }
  func remove() { try? FileManager.default.removeItem(at: directory) }
}
private actor SyncTestRemote: TaskSyncRemote {
  var snapshot: Snapshot
  var offline = true
  var loseCreate = false
  var reject = false
  var pause = false
  var started = false
  var waiting: CheckedContinuation<Void, Never>?
  var release: CheckedContinuation<Void, Never>?
  init(snapshot: Snapshot) { self.snapshot = snapshot }
  func setOffline(_ value: Bool) { offline = value }
  func loseNextCreateResponse() { loseCreate = true }
  func rejectPatches(_ value: Bool) { reject = value }
  func pauseNextPatch() { pause = true; started = false }
  func waitForPatch() async {
    if started { return }
    await withCheckedContinuation { waiting = $0 }
  }
  func releasePatch() { release?.resume(); release = nil }
  func load() throws -> Snapshot {
    if offline { throw URLError(.cannotConnectToHost) }
    return snapshot
  }
  func createTask(id: UUID, input: TaskInput) throws -> TaskRecord {
    if offline { throw URLError(.cannotConnectToHost) }
    if let existing = snapshot.tasks.first(where: { $0.id == id }) { return existing }
    try TrackerRules.validate(input, id: nil, in: snapshot)
    let task = TaskRecord(id: id, input: input)
    snapshot.receive(.task(task))
    if loseCreate { loseCreate = false; throw URLError(.networkConnectionLost) }
    return task
  }
  func apply(_ change: Change) async throws -> ChangeResult {
    if offline { throw URLError(.cannotConnectToHost) }
    let result: ChangeResult
    switch change {
    case .task(let id, let input):
      if reject { throw TrackerError.conflict("Server rejected update") }
      if pause {
        pause = false; started = true; waiting?.resume(); waiting = nil
        await withCheckedContinuation { release = $0 }
      }
      guard let task = snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
      try TrackerRules.validate(input, id: id, in: snapshot)
      result = .task(TaskRecord(id: task.id, input: input, completed: task.completed, createdAt: task.createdAt))
    case .completed(let id, let completed):
      guard var task = snapshot.tasks.first(where: { $0.id == id }) else { throw TrackerError.notFound }
      task.completed = completed; result = .task(task)
    case .deleteTask(let id):
      guard snapshot.tasks.contains(where: { $0.id == id }) else { throw TrackerError.notFound }
      result = .deleted(.task, id)
    default: throw TrackerError.validation("Unsupported test operation")
    }
    snapshot.receive(result)
    return result
  }
}
