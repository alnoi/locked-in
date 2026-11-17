import Foundation

public enum WorkdayPreferences {
  public static var startMinutes: Int {
    get { minutes("trackit.workday.start", fallback: 9 * 60) }
    set { UserDefaults.standard.set(min(1439, max(0, newValue)), forKey: "trackit.workday.start") }
  }
  public static var endMinutes: Int {
    get { minutes("trackit.workday.end", fallback: 21 * 60) }
    set { UserDefaults.standard.set(min(1439, max(0, newValue)), forKey: "trackit.workday.end") }
  }
  private static func minutes(_ key: String, fallback: Int) -> Int {
    guard UserDefaults.standard.object(forKey: key) != nil else { return fallback }
    return min(1439, max(0, UserDefaults.standard.integer(forKey: key)))
  }
}
