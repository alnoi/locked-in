import Foundation
import LockedInData

extension AppModel {
  func submitBugReport(id: UUID, description: String, screenshot: Data?) async throws {
    let token = authSession.flatMap { $0.expiresAt > .now ? $0.accessToken : nil }
    try await BugReportClient(address: settings.serverAddress).send(id: id, description: description, screenshot: screenshot, token: token)
  }
}
