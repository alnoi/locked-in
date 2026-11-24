import Foundation
import Security
import LockedInDomain

public enum AuthSessionStore {
  private static let service = "com.alan.planner.auth"
  private static func account(_ address: String, _ id: UUID) -> String { address + ":" + id.uuidString }
  private static func activeKey(_ address: String) -> String { "trackit.auth.active:" + address }
  private static func query(_ address: String, _ id: UUID) -> [CFString: Any] {
    var value: [CFString: Any] = [kSecClass: kSecClassGenericPassword,
      kSecAttrService: service, kSecAttrAccount: account(address, id)]
    #if os(iOS)
    value[kSecAttrAccessGroup] = "group.com.alan.planner"
    #endif
    return value
  }
  public static func activeUserID(address: String) -> UUID? {
    UserDefaults.standard.string(forKey: activeKey(address)).flatMap(UUID.init(uuidString:))
  }
  public static func active(address: String) throws -> AuthSession? {
    guard let id = activeUserID(address: address) else { return nil }
    return try load(address: address, userID: id)
  }
  public static func load(address: String, userID: UUID) throws -> AuthSession? {
    var attributes = query(address, userID)
    attributes[kSecReturnData] = true
    attributes[kSecMatchLimit] = kSecMatchLimitOne
    if Bundle.main.bundleURL.pathExtension == "appex" {
      attributes[kSecUseAuthenticationUI] = kSecUseAuthenticationUIFail
    }
    var result: CFTypeRef?
    let status = SecItemCopyMatching(attributes as CFDictionary, &result)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = result as? Data else { throw keychainError(status) }
    return try JSONCodec.decoder().decode(AuthSession.self, from: data)
  }
  public static func save(_ session: AuthSession, address: String) throws {
    let data = try JSONCodec.encoder().encode(session)
    let attributes = query(address, session.user.id)
    let status = SecItemUpdate(attributes as CFDictionary, [kSecValueData: data] as CFDictionary)
    if status == errSecItemNotFound {
      var inserted = attributes
      inserted[kSecValueData] = data
      #if os(macOS)
      var applications: [SecTrustedApplication] = []
      var urls = [Bundle.main.executableURL].compactMap { $0 }
      if let plugins = Bundle.main.builtInPlugInsURL,
        let extensionBundle = Bundle(url: plugins.appendingPathComponent("LockedInWidgets.appex")),
        let executable = extensionBundle.executableURL { urls.append(executable) }
      for url in urls {
        var application: SecTrustedApplication?
        let result = SecTrustedApplicationCreateFromPath(url.path, &application)
        guard result == errSecSuccess, let application else { throw keychainError(result) }
        applications.append(application)
      }
      var access: SecAccess?
      let accessStatus = SecAccessCreate("TrackIt account" as CFString, applications as CFArray, &access)
      guard accessStatus == errSecSuccess, let access else { throw keychainError(accessStatus) }
      inserted[kSecAttrAccess] = access
      #else
      inserted[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      #endif
      let added = SecItemAdd(inserted as CFDictionary, nil)
      guard added == errSecSuccess else { throw keychainError(added) }
    } else if status != errSecSuccess { throw keychainError(status) }
    UserDefaults.standard.set(session.user.id.uuidString, forKey: activeKey(address))
  }
  public static func remove(address: String, userID: UUID) throws {
    let status = SecItemDelete(query(address, userID) as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else { throw keychainError(status) }
    UserDefaults.standard.removeObject(forKey: activeKey(address))
  }
  private static func keychainError(_ status: OSStatus) -> NSError {
    NSError(domain: NSOSStatusErrorDomain, code: Int(status), userInfo: [NSLocalizedDescriptionKey:
      "Не удалось открыть защищённое хранилище аккаунта. " + (SecCopyErrorMessageString(status, nil) as String? ?? "Попробуй снова.")])
  }
}
