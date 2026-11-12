import Foundation
import LockedInDomain

public enum StorageMode: String, CaseIterable, Identifiable, Sendable {
    case local, server
    public var id: String { rawValue }
    public var title: String { self == .local ? "На устройстве" : "Сервер" }
}
public struct ConnectionSettings: Sendable {
    public var mode: StorageMode
    public var serverAddress: String
    public init(mode: StorageMode, serverAddress: String = "http://127.0.0.1:8080") { self.mode = mode; self.serverAddress = serverAddress }
    public static var saved: ConnectionSettings {
        #if targetEnvironment(simulator) || os(macOS)
        let defaultMode: StorageMode = .server
        #else
        let defaultMode: StorageMode = .local
        #endif
        if let address = ProcessInfo.processInfo.environment["LOCKED_IN_SERVER_URL"] { return ConnectionSettings(mode: .server, serverAddress: address) }
        return ConnectionSettings(mode: UserDefaults.standard.string(forKey: "storageMode").flatMap(StorageMode.init) ?? defaultMode, serverAddress: UserDefaults.standard.string(forKey: "serverAddress") ?? "http://127.0.0.1:8080")
    }
    public func save() { UserDefaults.standard.set(mode.rawValue, forKey: "storageMode"); UserDefaults.standard.set(serverAddress, forKey: "serverAddress") }
    public func validatedURL() throws -> URL {
        guard let url = URL(string: serverAddress.trimmingCharacters(in: .whitespacesAndNewlines)), let host = url.host,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/", url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1", "[::1]"].contains(host))
        else { throw TrackerError.validation("Укажи HTTPS-адрес сервера или http://127.0.0.1:8080 для локального запуска.") }
        return url
    }
    public var identity: String { mode == .local ? "local" : "server:" + serverAddress }
    public static var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LockedIn", isDirectory: true)
    }
    public func repository() throws -> any TrackerRepository {
        if mode == .local { return LocalRepository(file: Self.supportDirectory.appendingPathComponent("local_v1.json")) }
        return HTTPRepository(baseURL: try validatedURL())
    }
}
