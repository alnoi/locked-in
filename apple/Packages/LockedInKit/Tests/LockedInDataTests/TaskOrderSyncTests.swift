import Foundation
import LockedInDomain
import XCTest
@testable import LockedInData

final class TaskOrderSyncTests: XCTestCase {
  func testOfflineOrderSurvivesRestartAndReachesAnotherDevice() async throws {
    let fixture = try OrderSyncFixture()
    defer { fixture.remove() }
    let first = fixture.repository("first")
    _ = try await first.load()
    await fixture.remote.setOffline(true)
    let desired = Array(fixture.ids.reversed())
    _ = try await first.saveTaskOrder(desired, initializeOnly: false)
    let restarted = fixture.repository("first")
    let offline = try await restarted.load()
    XCTAssertEqual(offline.taskOrder?.taskIDs, desired)
    let pending = await restarted.status()
    XCTAssertTrue(pending.hasPendingTaskOrder)
    await fixture.remote.setOffline(false)
    _ = try await restarted.load()
    let second = try await fixture.repository("second").load()
    XCTAssertEqual(second.taskOrder?.taskIDs, desired)
    let finished = await restarted.status()
    XCTAssertFalse(finished.hasPendingTaskOrder)
  }
  func testNewOfflineTaskIsUploadedBeforeItsOrder() async throws {
    let fixture = try OrderSyncFixture()
    defer { fixture.remove() }
    let repository = fixture.repository("first")
    _ = try await repository.load()
    await fixture.remote.setOffline(true)
    guard case .task(let task) = try await repository.apply(.task(nil, TaskInput(title: "New offline task"))) else {
      return XCTFail("Expected new task")
    }
    let desired = [task.id] + fixture.ids
    _ = try await repository.saveTaskOrder(desired, initializeOnly: false)
    await fixture.remote.setOffline(false)
    let synced = try await repository.load()
    XCTAssertEqual(synced.taskOrder?.taskIDs, desired)
    XCTAssertTrue(synced.tasks.contains { $0.id == task.id })
    let status = await repository.status()
    XCTAssertTrue(status.pendingTaskIDs.isEmpty)
    XCTAssertFalse(status.hasPendingTaskOrder)
  }
  func testOldAcknowledgementDoesNotDiscardNewerOrder() async throws {
    let fixture = try OrderSyncFixture()
    defer { fixture.remove() }
    let repository = fixture.repository("first")
    _ = try await repository.load()
    _ = try await repository.saveTaskOrder(Array(fixture.ids.reversed()), initializeOnly: false)
    await fixture.remote.pauseNextOrder()
    let loading = Task { try await repository.load() }
    await fixture.remote.waitForOrder()
    let desired = [fixture.ids[1], fixture.ids[2], fixture.ids[0]]
    _ = try await repository.saveTaskOrder(desired, initializeOnly: false)
    await fixture.remote.releaseOrder()
    let interim = try await loading.value
    XCTAssertEqual(interim.taskOrder?.taskIDs, desired)
    let pending = await repository.status()
    XCTAssertTrue(pending.hasPendingTaskOrder)
    let synced = try await repository.load()
    XCTAssertEqual(synced.taskOrder?.taskIDs, desired)
    let finished = await repository.status()
    XCTAssertFalse(finished.hasPendingTaskOrder)
  }
  func testLegacyOrderImportedOnceAndServerWinsOnAnotherDevice() async throws {
    let fixture = try OrderSyncFixture(revision: 0)
    defer { fixture.remove() }
    let local = Array(fixture.ids.reversed())
    TaskOrderPreferences.save(local, space: fixture.space, userID: fixture.snapshot.user.id)
    let imported = try await fixture.repository("first").load()
    XCTAssertEqual(imported.taskOrder?.taskIDs, local)
    let newer = [fixture.ids[1], fixture.ids[0], fixture.ids[2]]
    _ = try await fixture.remote.saveTaskOrder(newer, initializeOnly: false)
    let second = try await fixture.repository("second").load()
    XCTAssertEqual(second.taskOrder?.taskIDs, newer)
  }
  func testPartialOfflineOrderKeepsHiddenTasksAndIgnoresDeletedTask() async throws {
    let fixture = try OrderSyncFixture()
    defer { fixture.remove() }
    let repository = fixture.repository("first")
    _ = try await repository.load()
    _ = try await repository.saveTaskOrder([fixture.ids[2],fixture.ids[0]], initializeOnly: false)
    let local = try await repository.restore()
    XCTAssertEqual(local?.taskOrder?.taskIDs, [fixture.ids[2],fixture.ids[1],fixture.ids[0]])
    await fixture.remote.deleteTask(fixture.ids[1])
    let synced = try await repository.load()
    XCTAssertEqual(synced.taskOrder?.taskIDs, [fixture.ids[2],fixture.ids[0]])
  }
  func testPendingOrderDoesNotMoveIntoAnotherAccount() async throws {
    let fixture = try OrderSyncFixture()
    defer { fixture.remove() }
    let repository = fixture.repository("first")
    _ = try await repository.load()
    _ = try await repository.saveTaskOrder(Array(fixture.ids.reversed()), initializeOnly: false)
    await fixture.remote.switchUser()
    do { _ = try await repository.load(); XCTFail("Cross-account load must fail") }
    catch { XCTAssertTrue(error is TrackerError) }
    let restored = try await repository.restore()
    XCTAssertEqual(restored?.user.id, fixture.snapshot.user.id)
  }
}

private struct OrderSyncFixture {
  let directory: URL
  let snapshot: Snapshot
  let ids: [UUID]
  let remote: OrderSyncRemote
  let space = "order-test-" + UUID().uuidString
  init(revision: Int64 = 1) throws {
    directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let tasks = (0..<3).map { index in TaskRecord(input: TaskInput(title: "Task \(index)"), createdAt: Date(timeIntervalSince1970: Double(index))) }
    ids = tasks.map(\.id)
    snapshot = Snapshot(tasks: tasks, taskOrder: TaskOrder(taskIDs: ids, revision: revision))
    remote = OrderSyncRemote(snapshot: snapshot)
    try JSONCodec.encoder().encode(snapshot).write(to: directory.appendingPathComponent("seed.json"))
  }
  func repository(_ name: String) -> OfflineTaskRepository {
    OfflineTaskRepository(remote: remote, file: directory.appendingPathComponent(name + ".json"), seedFile: directory.appendingPathComponent("seed.json"), orderSpace: space)
  }
  func remove() {
    try? FileManager.default.removeItem(at: directory)
    UserDefaults.standard.removeObject(forKey: "taskOrder:" + space + ":" + snapshot.user.id.uuidString)
  }
}
private actor OrderSyncRemote: TaskSyncRemote, TaskOrderRepository {
  var snapshot: Snapshot
  var offline = false
  var pause = false
  var started = false
  var waiting: CheckedContinuation<Void, Never>?
  var release: CheckedContinuation<Void, Never>?
  init(snapshot: Snapshot) { self.snapshot = snapshot }
  func setOffline(_ value: Bool) { offline = value }
  func switchUser() { snapshot.user = UserRecord() }
  func deleteTask(_ id: UUID) { snapshot.tasks.removeAll { $0.id == id } }
  func pauseNextOrder() { pause = true; started = false }
  func waitForOrder() async {
    if started { return }
    await withCheckedContinuation { waiting = $0 }
  }
  func releaseOrder() { release?.resume(); release = nil }
  func load() throws -> Snapshot {
    if offline { throw URLError(.cannotConnectToHost) }
    return snapshot
  }
  func saveTaskOrder(_ ids: [UUID], initializeOnly: Bool) async throws -> TaskOrder {
    if offline { throw URLError(.cannotConnectToHost) }
    if pause {
      pause = false; started = true; waiting?.resume(); waiting = nil
      await withCheckedContinuation { release = $0 }
    }
    let current = snapshot.taskOrder ?? TaskOrder()
    if initializeOnly && current.revision > 0 { return current }
    let canonical = TaskOrdering.orderedIDs(snapshot.tasks, stored: current.taskIDs)
    let order = TaskOrder(taskIDs: TaskOrdering.merging(ids, into: canonical), revision: current.revision + 1)
    snapshot.taskOrder = order
    return order
  }
  func createTask(id: UUID, input: TaskInput) throws -> TaskRecord {
    if offline { throw URLError(.cannotConnectToHost) }
    if let existing = snapshot.tasks.first(where: { $0.id == id }) { return existing }
    let task = TaskRecord(id: id, input: input)
    snapshot.receive(.task(task))
    return task
  }
  func apply(_ change: Change) throws -> ChangeResult {
    if offline { throw URLError(.cannotConnectToHost) }
    guard case .task(let id, let input) = change,
      let existing = snapshot.tasks.first(where: { $0.id == id }) else { throw RequestFailure.unsupportedAction }
    let task = TaskRecord(id: existing.id, input: input, completed: existing.completed, createdAt: existing.createdAt)
    snapshot.receive(.task(task))
    return .task(task)
  }
}
