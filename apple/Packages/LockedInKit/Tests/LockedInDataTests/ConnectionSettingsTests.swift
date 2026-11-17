import XCTest
@testable import LockedInData

final class ConnectionSettingsTests: XCTestCase {
  func testExplicitServerAddressSurvivesReloadAndOverridesBootstrapEnvironment() throws {
    let suite = "ConnectionSettingsTests." + UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let address = "http://127.0.0.1:19999"
    let settings = ConnectionSettings(mode: .server, serverAddress: address)
    _ = try settings.validatedURL()
    settings.save(defaults: defaults)
    let restored = ConnectionSettings.read(defaults: UserDefaults(suiteName: suite)!, environment: ["LOCKED_IN_SERVER_URL": "http://127.0.0.1:8080"])
    XCTAssertEqual(restored.serverAddress, address)
    XCTAssertEqual(restored.mode, .server)
  }
}
