import SwiftUI

struct DayCompletionCelebration: View {
  var token: UUID
  var dismiss: () -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var started = Date.now
  private let colors: [Color] = [.purple, .mint, .yellow, .pink, .cyan]
  var body: some View {
    ZStack(alignment: .top) {
      if !reduceMotion {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
          Canvas { graphics, size in
            let elapsed = context.date.timeIntervalSince(started)
            for index in 0..<65 {
              let delay = Double(index % 9) * 0.035
              let progress = max(0, (elapsed - delay) / 3.2)
              guard progress > 0, progress < 1 else { continue }
              let seed = Double((index * 47) % 101) / 100
              let x = size.width * (0.1 + seed * 0.8) + sin(progress * 8 + Double(index)) * 32
              let y = -20 + progress * (size.height * 0.85 + 20)
              var particle = graphics
              particle.opacity = min(1, (1 - progress) * 3)
              particle.translateBy(x: x, y: y)
              particle.rotate(by: .radians(progress * Double(index % 5 + 2) * 4))
              particle.fill(Path(roundedRect: CGRect(x: -3, y: -5, width: index % 2 == 0 ? 5 : 8, height: 9), cornerRadius: 1.5), with: .color(colors[index % colors.count]))
            }
          }
        }
      }
      VStack(spacing: 7) {
        Image(systemName: "checkmark.seal.fill").font(.system(size: 30)).foregroundStyle(.mint)
        Text("Сегодня вы молодец!").font(.title3.bold())
        Text("Так держать.").font(.subheadline).foregroundStyle(.secondary)
      }.padding(.horizontal, 30).padding(.vertical, 20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))
        .overlay { RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.12)) }
        .shadow(color: .black.opacity(0.12), radius: 18, y: 8).padding(.top, 24)
    }.allowsHitTesting(false)
      .accessibilityElement(children: .combine)
      .task(id: token) {
        started = .now
        do { try await Task.sleep(for: .seconds(4)) } catch { return }
        dismiss()
      }
  }
}
