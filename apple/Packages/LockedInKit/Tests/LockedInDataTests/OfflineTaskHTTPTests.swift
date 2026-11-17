import Foundation
import LockedInDomain
import XCTest
@testable import LockedInData

final class OfflineTaskHTTPTests: XCTestCase {
  func testOfflineRestartAndLostResponseAgainstDedicatedBackend() async throws {
    guard let address = ProcessInfo.processInfo.environment["LOCKED_IN_TEST_SERVER"], let url = URL(string: address) else {
      throw XCTSkip("Dedicated test backend required")
    }
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [OfflineGateProtocol.self]
    let session = URLSession(configuration: config)
    defer { session.invalidateAndCancel(); OfflineGateProtocol.setOffline(false) }
    let remote = HTTPRepository(baseURL: url, session: session)
    let initial = try await remote.load()
    guard initial.user.username == "apple_mvp_test" else { return XCTFail("Refusing to modify non-test data") }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("queue.json")
    let first = OfflineTaskRepository(remote: remote, file: file)
    _ = try await first.load()
    OfflineGateProtocol.setOffline(true)
    guard case .task(let task) = try await first.apply(.task(nil, TaskInput(title: "Offline HTTP " + UUID().uuidString))) else { return XCTFail() }
    let reopened = OfflineTaskRepository(remote: remote, file: file)
    let offline = try await reopened.load()
    XCTAssertTrue(offline.tasks.contains { $0.id == task.id })
    OfflineGateProtocol.setOffline(false)
    OfflineGateProtocol.loseNextCreate()
    _ = try await reopened.load()
    let failed = await reopened.status()
    XCTAssertTrue(failed.pendingTaskIDs.contains(task.id))
    var edited = TaskInput(task); edited.title = "Changed after a lost response"; edited.durationMinutes = 45
    _ = try await reopened.apply(.task(task.id, edited))
    _ = try await reopened.apply(.completed(task.id, true))
    _ = try await reopened.load()
    let synced = await reopened.status()
    XCTAssertFalse(synced.pendingTaskIDs.contains(task.id))
    let server = try await remote.load()
    let matches = server.tasks.filter { $0.id == task.id }
    XCTAssertEqual(matches.count, 1)
    XCTAssertEqual(matches.first?.title, edited.title)
    XCTAssertEqual(matches.first?.durationMinutes, 45)
    XCTAssertEqual(matches.first?.completed, true)
    _ = try await remote.apply(.deleteTask(task.id))
  }
}
private final class OfflineGateProtocol: URLProtocol, @unchecked Sendable {
  private static let lock = NSLock()
  private static var offline = false
  private static var loseCreate = false
  private var forwarding: URLSessionDataTask?
  static func setOffline(_ value: Bool) { lock.withLock { offline = value } }
  static func loseNextCreate() { lock.withLock { loseCreate = true } }
  override class func canInit(with request: URLRequest) -> Bool { true }
  override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
  override func startLoading() {
    if Self.lock.withLock({ Self.offline }) {
      client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
      return
    }
    var forwarded = request
    if forwarded.httpBody == nil, let stream = request.httpBodyStream {
      stream.open(); defer { stream.close() }
      var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
      while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
      }
      forwarded.httpBody = data
    }
    forwarding = URLSession.shared.dataTask(with: forwarded) { [self] data, response, error in
      if let error { client?.urlProtocol(self, didFailWithError: error); return }
      let lose = Self.lock.withLock {
        if Self.loseCreate && request.httpMethod == "POST" && request.url?.path.hasSuffix("/tasks") == true {
          Self.loseCreate = false; return true
        }
        return false
      }
      if lose { client?.urlProtocol(self, didFailWithError: URLError(.networkConnectionLost)); return }
      if let response { client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed) }
      if let data { client?.urlProtocol(self, didLoad: data) }
      client?.urlProtocolDidFinishLoading(self)
    }
    forwarding?.resume()
  }
  override func stopLoading() { forwarding?.cancel() }
}
