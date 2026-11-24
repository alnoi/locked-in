import Foundation

public enum ProfilePreferences {
  private static let keys = ["trackit.appearance", "trackit.accentColor", "trackit.sidebar.collapsedBoards",
    "trackit.workday.start", "trackit.workday.end", "reminderDateOnlyMinutes", "taskReminderSnoozes"]
  public static func migrateLegacy(settings: ConnectionSettings, defaults: UserDefaults = .standard) {
    guard settings.hasLegacyProfileData, let userID = settings.accountID else { return }
    let marker = "trackit.preferences.migrated:" + settings.identity
    guard !defaults.bool(forKey: marker) else { return }
    let old = "server:" + settings.serverAddress
    for prefix in ["listOrder:", "taskOrder:"] {
      let key = prefix + settings.identity + ":" + userID.uuidString
      if defaults.object(forKey: key) == nil,
        let value = defaults.object(forKey: prefix + old + ":" + userID.uuidString) { defaults.set(value, forKey: key) }
    }
    let oldSpace = old + ":" + userID.uuidString
    let newSpace = settings.identity + ":" + userID.uuidString
    for (prefix, suffixes) in [("trackit.dayProgress.", [".seen", ".celebrated"]), ("trackit.daySummary.", [""])] {
      for suffix in suffixes {
        let key = prefix + Data(newSpace.utf8).base64EncodedString() + suffix
        if defaults.object(forKey: key) == nil,
          let value = defaults.object(forKey: prefix + Data(oldSpace.utf8).base64EncodedString() + suffix) { defaults.set(value, forKey: key) }
      }
    }
    if let data = defaults.data(forKey: "taskReminderSnoozes"),
      var values = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] {
      for key in Array(values.keys) {
        if let signature = values[key]?["signature"] as? String, signature.hasPrefix("v2:" + oldSpace + ":") {
          values[key]?["signature"] = signature.replacingOccurrences(of: "v2:" + oldSpace + ":", with: "v2:" + newSpace + ":")
        }
      }
      if let updated = try? JSONSerialization.data(withJSONObject: values) { defaults.set(updated, forKey: "taskReminderSnoozes") }
    }
    defaults.set(true, forKey: marker)
  }
  public static func activate(_ scope: String, inheritLegacy: Bool = false, defaults: UserDefaults = .standard) {
    let activeKey = "trackit.preferences.activeProfile"
    guard defaults.string(forKey: activeKey) != scope else { return }
    let old = defaults.string(forKey: activeKey) ?? "legacy"
    let values = Dictionary(uniqueKeysWithValues: keys.compactMap { key in defaults.object(forKey: key).map { (key, $0) } })
    defaults.set(values, forKey: "trackit.preferences:" + old)
    let restored = defaults.dictionary(forKey: "trackit.preferences:" + scope)
      ?? (inheritLegacy ? defaults.dictionary(forKey: "trackit.preferences:legacy") : nil) ?? [:]
    for key in keys {
      if let value = restored[key] { defaults.set(value, forKey: key) }
      else { defaults.removeObject(forKey: key) }
    }
    defaults.set(scope, forKey: activeKey)
  }
}
