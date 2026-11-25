import Foundation
import LockedInDomain

public enum StorageMode: String, CaseIterable, Identifiable, Codable, Sendable {
    case local, server
    public var id: String { rawValue }
    public var title: String { self == .local ? "На устройстве" : "Сервер" }
}
public struct ConnectionSettings: Sendable {
    public var mode: StorageMode
    public var accountID: UUID?
    public var serverAddress: String
    public init(mode: StorageMode, serverAddress: String = "http://127.0.0.1:8080", accountID: UUID? = nil) { self.mode = mode; self.serverAddress = serverAddress; self.accountID = accountID }
    public static var saved: ConnectionSettings { read(defaults: .standard) }
    public static func read(defaults: UserDefaults, environment: [String: String] = ProcessInfo.processInfo.environment) -> ConnectionSettings {
        #if targetEnvironment(simulator) || os(macOS)
        let defaultMode: StorageMode = .server
        #else
        let defaultMode: StorageMode = .server
        #endif
        let mode = defaults.string(forKey: "storageMode").flatMap(StorageMode.init)
            ?? (environment["LOCKED_IN_SERVER_URL"] == nil ? defaultMode : .server)
        let address = defaults.string(forKey: "serverAddress") ?? environment["LOCKED_IN_SERVER_URL"] ?? "http://127.0.0.1:8080"
        return ConnectionSettings(mode: mode, serverAddress: address, accountID: AuthSessionStore.activeUserID(address: address))
    }
    public func save(defaults: UserDefaults = .standard) {
        defaults.set(mode.rawValue, forKey: "storageMode")
        defaults.set(serverAddress, forKey: "serverAddress")
    }
    public func validatedURL() throws -> URL {
        guard let url = URL(string: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)), let host = url.host,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/", url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host))
        else { throw TrackerError.validation("Укажи HTTPS-адрес сервера или http://127.0.0.1:8080 для локального запуска.") }
        return url
    }
    public var identity: String { mode == .local ? "local" : "server:" + serverAddress + (accountID.map { ":user:" + $0.uuidString } ?? "") }
    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LockedIn", isDirectory: true)
    }
    public var hasLegacyProfileData: Bool {
        guard mode == .server, let accountID else { return false }
        let key = Data(("server:" + serverAddress).utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        let file = Self.supportDirectory.appendingPathComponent("sync_" + key + ".json")
        guard let data = try? Data(contentsOf: file),
          let archive = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let snapshot = archive["snapshot"] as? [String: Any], let user = snapshot["user"] as? [String: Any],
          let value = user["id"] as? String else { return false }
        return UUID(uuidString: value) == accountID
    }
    public func repository() throws -> any TrackerRepository {
        if mode == .local { return LocalRepository(file: Self.supportDirectory.appendingPathComponent("local_v1.json")) }
        guard let accountID, let session = try AuthSessionStore.load(address: serverAddress, userID: accountID),
          session.expiresAt > .now else { throw AuthenticationError.sessionExpired }
        let key = Data(identity.utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
        let file = Self.supportDirectory.appendingPathComponent("sync_" + key + ".json")
        if !FileManager.default.fileExists(atPath: file.path) {
          let legacyKey = Data(("server:" + serverAddress).utf8).base64EncodedString().replacingOccurrences(of: "/", with: "_")
          let legacy = Self.supportDirectory.appendingPathComponent("sync_" + legacyKey + ".json")
          if FileManager.default.fileExists(atPath: legacy.path) {
            let data = try Data(contentsOf: legacy)
            if let archive = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let snapshot = archive["snapshot"] as? [String: Any], let user = snapshot["user"] as? [String: Any],
              let value = user["id"] as? String, UUID(uuidString: value) == accountID {
              try data.write(to: file, options: .atomic)
            }
          }
        }
        return OfflineTaskRepository(remote: HTTPRepository(baseURL: try validatedURL(), accessToken: session.accessToken),
          file: file,
          seedFile: Self.supportDirectory.appendingPathComponent("cache_" + key + ".json"), orderSpace: identity)
    }
}
