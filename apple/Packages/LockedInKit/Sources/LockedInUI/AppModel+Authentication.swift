import Foundation
import OSLog
import LockedInData
import LockedInDomain

extension AppModel {
  func authenticate(username: String, password: String, registering: Bool, emoji: String,
    address: String) async throws {
    let client = try AuthenticationClient(address: address)
    let session: AuthSession
    if registering { session = try await client.register(username: username, password: password, emoji: emoji) }
    else { session = try await client.login(username: username, password: password) }
    try AuthSessionStore.save(session, address: address)
    UserDefaults.standard.set(session.user.username, forKey: "trackit.auth.lastUsername:" + address)
    authSession = session
    needsAuthentication = false
    try await connect(ConnectionSettings(mode: .server, serverAddress: address, accountID: session.user.id))
    if needsAuthentication { throw AuthenticationError.sessionExpired }
  }
  func updateAvatar(_ emoji: String) async throws {
    guard emoji.isEmpty || ProfileEmoji.valid(emoji) else { throw RequestFailure.invalidAvatar }
    guard var session = authSession else { throw AuthenticationError.sessionExpired }
    let source = settings.identity
    let user = try await AuthenticationClient(address: settings.serverAddress).updateAvatar(emoji, token: session.accessToken)
    guard settings.identity == source, authSession?.user.id == user.id else { return }
    session.user = user
    try AuthSessionStore.save(session, address: settings.serverAddress)
    authSession = session
    snapshot.user = user
    cacheSnapshot()
  }
  func signOut() async throws {
    guard !isMutating else { throw TrackerError.conflict("Дождись сохранения текущего изменения.") }
    let previous = authSession
    let address = settings.serverAddress
    if let session = previous { try AuthSessionStore.remove(address: address, userID: session.user.id) }
    authSession = nil
    needsAuthentication = true
    await clearProfilePresentation()
    errorMessage = nil
    if let previous {
      do { try await AuthenticationClient(address: address).logout(token: previous.accessToken) }
      catch { Logger(subsystem: "com.alan.planner", category: "auth").notice("Server logout could not be delivered") }
    }
  }
  func requireAuthentication(_ error: Error?) async {
    authSession = nil
    needsAuthentication = true
    await clearProfilePresentation()
    errorMessage = error.map { friendly($0) }
  }
}
