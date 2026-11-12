import Foundation

public enum CalendarSnapping {
  public static func minute(_ proposed: Double, boundaries: [Double], minimum: Double = 0, maximum: Double = 1439) -> Double {
    let grid = (proposed / 15).rounded() * 15
    let nearby = boundaries.filter { $0 >= minimum && $0 <= maximum && abs($0 - proposed) <= 5 }
      .sorted { abs($0 - proposed) == abs($1 - proposed) ? $0 < $1 : abs($0 - proposed) < abs($1 - proposed) }
    return min(maximum, max(minimum, nearby.first ?? grid))
  }
}
