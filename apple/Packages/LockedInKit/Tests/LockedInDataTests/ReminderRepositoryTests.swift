import Foundation
import LockedInDomain
import XCTest

@testable import LockedInData

final class ReminderRepositoryTests: XCTestCase {
  func testReminderPersistsLocallyAndOldTaskStillDecodes() async throws {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
      UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: file) }
    let input = TaskInput(
      title: "Reminder", deadlineAt: Date(timeIntervalSince1970: 2_000_000_000),
      reminderMode: .alarm, reminderMinutesBefore: 15)
    let repository = LocalRepository(file: file)
    guard case .task(let created) = try await repository.apply(.task(nil, input)) else {
      return XCTFail("No task")
    }
    let snapshot = try await LocalRepository(file: file).load()
    XCTAssertEqual(snapshot.tasks.first?.reminderMode, .alarm)
    XCTAssertEqual(snapshot.tasks.first?.reminderMinutesBefore, 15)
    var object =
      try JSONSerialization.jsonObject(with: JSONCodec.encoder().encode(created)) as! [String: Any]
    object.removeValue(forKey: "reminderMode")
    object.removeValue(forKey: "reminderMinutesBefore")
    let old = try JSONCodec.decoder().decode(
      TaskRecord.self, from: JSONSerialization.data(withJSONObject: object))
    XCTAssertNil(old.reminderMode)
    XCTAssertNil(TaskReminder.fireDate(for: old))
  }
  func testHTTPReminderRoundTripAndUnrelatedEdit() async throws {
    guard let address = ProcessInfo.processInfo.environment["LOCKED_IN_TEST_SERVER"],
      let url = URL(string: address)
    else { throw XCTSkip("Dedicated test backend required") }
    let repository = HTTPRepository(baseURL: url)
    let snapshot = try await repository.load()
    guard snapshot.user.username == "apple_mvp_test" else {
      return XCTFail("Refusing non-test backend")
    }
    let input = TaskInput(
      title: "Reminder round trip", plannedAt: Date(timeIntervalSince1970: 2_000_000_000),
      reminderMode: .alarm, reminderMinutesBefore: 5)
    guard case .task(let created) = try await repository.apply(.task(nil, input)) else {
      return XCTFail("No task")
    }
    var renamed = TaskInput(created)
    renamed.title = "Renamed"
    guard case .task(let updated) = try await repository.apply(.task(created.id, renamed)) else {
      return XCTFail("No task")
    }
    XCTAssertEqual(updated.reminderMode, .alarm)
    XCTAssertEqual(updated.reminderMinutesBefore, 5)
    XCTAssertEqual(updated.plannedAt, input.plannedAt)
    _ = try await repository.apply(.completed(created.id, true))
    let refreshed = try await repository.load()
    XCTAssertNil(TaskReminder.fireDate(for: refreshed.tasks.first { $0.id == created.id }!))
    _ = try await repository.apply(.deleteTask(created.id))
  }
}
