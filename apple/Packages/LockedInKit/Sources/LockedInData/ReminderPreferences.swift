import Foundation

public enum ReminderPreferences {
  public static var dateOnlyMinutes: Int {
    get {
      guard UserDefaults.standard.object(forKey: "reminderDateOnlyMinutes") != nil else {
        return 600
      }
      return min(1439, max(0, UserDefaults.standard.integer(forKey: "reminderDateOnlyMinutes")))
    }
    set {
      UserDefaults.standard.set(min(1439, max(0, newValue)), forKey: "reminderDateOnlyMinutes")
    }
  }
}
