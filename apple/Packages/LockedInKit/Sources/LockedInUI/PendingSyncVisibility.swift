import Foundation

struct PendingSyncVisibility {
  private var firstSeen: [UUID: Date] = [:]
  mutating func update(_ pending: Set<UUID>, at date: Date) {
    firstSeen = firstSeen.filter { pending.contains($0.key) }
    for id in pending where firstSeen[id] == nil { firstSeen[id] = date }
  }
  func visible(at date: Date) -> Set<UUID> {
    Set(firstSeen.filter { date.timeIntervalSince($0.value) >= 1 }.map(\.key))
  }
  func nextAppearance(at date: Date) -> TimeInterval? {
    firstSeen.values.map { 1 - date.timeIntervalSince($0) }.filter { $0 > 0 }.min()
  }
}
