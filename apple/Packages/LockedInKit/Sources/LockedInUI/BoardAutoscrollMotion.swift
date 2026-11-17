import Foundation

struct BoardAutoscrollMotion {
  private var requested: CGFloat?
  private var previousTime: TimeInterval?
  private var startedAt: TimeInterval?
  private var direction: CGFloat = 0

  mutating func advance(velocity: CGFloat, offset: CGFloat, maximum: CGFloat,
    time: TimeInterval, speed: CGFloat = 480) -> CGFloat? {
    guard velocity != 0 else { self = Self(); return nil }
    let sign: CGFloat = velocity < 0 ? -1 : 1
    if direction != sign {
      self = Self()
      direction = sign
      startedAt = time
      previousTime = time
      requested = offset
      return nil
    }
    let elapsed = min(1.0 / 30, max(0, time - (previousTime ?? time)))
    previousTime = time
    let ramp = min(1, max(0, (time - (startedAt ?? time)) / 0.18))
    let limit = max(10, speed / 60)
    let current = min(offset + limit, max(offset - limit, requested ?? offset))
    var next = current + velocity * speed * elapsed * ramp
    next = min(maximum, max(0, min(offset + limit, max(offset - limit, next))))
    if sign > 0 { next = max(offset, next) } else { next = min(offset, next) }
    requested = next
    return abs(next - offset) > 0.1 ? next : nil
  }
}
