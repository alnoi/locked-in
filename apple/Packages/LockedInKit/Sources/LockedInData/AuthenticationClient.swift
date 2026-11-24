import Foundation
import LockedInDomain

public struct AuthenticationClient: Sendable {
  private let baseURL: URL
  public init(address: String) throws {
    baseURL = try ConnectionSettings(mode: .server, serverAddress: address).validatedURL()
  }
  public func login(username: String, password: String) async throws -> AuthSession {
    try await send("auth/login", method: "POST", body: ["username": username, "password": password])
  }
  public func register(username: String, password: String, emoji: String) async throws -> AuthSession {
    try await send("auth/register", method: "POST", body: ["username": username, "password": password,
      "avatarEmoji": emoji, "timeZone": TimeZone.current.identifier])
  }
  public func updateAvatar(_ emoji: String, token: String) async throws -> UserRecord {
    try await send("me", method: "PATCH", token: token, body: ["avatarEmoji": emoji])
  }
  public func logout(token: String) async throws {
    _ = try await request("api/v1/auth/logout", method: "POST", token: token)
  }
  public func ping() async throws {
    _ = try await request("readyz", method: "GET")
  }
  private func send<Value: Decodable>(_ path: String, method: String, token: String? = nil,
    body: [String: String]) async throws -> Value {
    let data = try await request("api/v1/" + path, method: method, token: token, body: body)
    return try JSONCodec.decoder().decode(Value.self, from: data)
  }
  private func request(_ path: String, method: String, token: String? = nil,
    body: [String: String]? = nil) async throws -> Data {
    var request = URLRequest(url: baseURL.appendingPathComponent(path))
    request.httpMethod = method
    request.timeoutInterval = 15
    request.cachePolicy = .reloadIgnoringLocalCacheData
    if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
    if let body {
      request.httpBody = try JSONSerialization.data(withJSONObject: body)
      request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    }
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
    guard (200..<300).contains(response.statusCode) else {
      let operation: ServerFailureMapper.Operation
      switch path {
      case "api/v1/auth/login": operation = .login
      case "api/v1/auth/register": operation = .registration
      case "api/v1/me": operation = .profile
      default: operation = .ping
      }
      throw ServerFailureMapper.error(status: response.statusCode, data: data, operation: operation)
    }
    return data
  }
}
