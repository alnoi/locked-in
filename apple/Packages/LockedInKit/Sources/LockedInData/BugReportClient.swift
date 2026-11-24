import Foundation
import LockedInDomain

public struct BugReportClient {
  private let baseURL: URL
  public init(address: String) throws {
    baseURL = try ConnectionSettings(mode: .server, serverAddress: address).validatedURL()
  }
  private struct Receipt: Decodable { var id: UUID }
  public func send(id: UUID, description: String, screenshot: Data?, token: String?) async throws {
    var body: [String: Any] = ["id": id.uuidString, "description": description,
      "appVersion": String((Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev").prefix(64))]
    #if os(macOS)
    body["platform"] = "macos"
    #else
    body["platform"] = "ios"
    #endif
    if let screenshot {
      body["screenshotBase64"] = screenshot.base64EncodedString()
      body["screenshotMime"] = "image/jpeg"
    }
    var request = URLRequest(url: baseURL.appendingPathComponent("api/v1/bug-reports"))
    request.httpMethod = "POST"
    request.timeoutInterval = 20
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    let (data, response) = try await URLSession.shared.data(for: request)
    guard let response = response as? HTTPURLResponse else { throw RequestFailure.internalError }
    guard (200..<300).contains(response.statusCode) else {
      throw ServerFailureMapper.error(status: response.statusCode, data: data, operation: .report)
    }
    guard try JSONCodec.decoder().decode(Receipt.self, from: data).id == id else { throw RequestFailure.internalError }
  }
}
