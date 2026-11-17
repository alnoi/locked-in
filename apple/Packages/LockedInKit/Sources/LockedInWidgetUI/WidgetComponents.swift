import LockedInData
import LockedInDomain
import SwiftUI
import WidgetKit

extension Color {
  static let widgetAccent = Color(red: 0.396, green: 0.345, blue: 0.91)
  init(widgetHex: String?) {
    let value = UInt32((widgetHex ?? "#8B8B93").replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0x8B8B93
    self.init(red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255)
  }
}
struct WidgetBrand: View {
  var body: some View {
    Image(systemName: "scope").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.widgetAccent).widgetAccentable()
  }
}
struct WidgetEmpty: View {
  var connected: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Image(systemName: connected ? "checkmark.circle" : "arrow.up.forward.app")
        .font(.system(size: 24, weight: .light)).foregroundStyle(Color.widgetAccent)
      Text(connected ? "На сегодня всё" : "Открой TrackIt").font(.system(.headline, design: .rounded))
      Text(connected ? "Можно выдохнуть." : "Задачи появятся после открытия приложения.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }.frame(maxWidth: .infinity, alignment: .leading)
  }
}
struct WidgetProgress: View {
  var completed: Int
  var remaining: Int
  private var progress: Double { Double(completed) / Double(max(1, completed + remaining)) }
  var body: some View {
    ZStack {
      Circle().stroke(Color.widgetAccent.opacity(0.13), lineWidth: 3)
      Circle().trim(from: 0, to: progress).stroke(Color.widgetAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .rotationEffect(.degrees(-90)).widgetAccentable()
      Text("\(remaining)").font(.system(size: 11, weight: .semibold, design: .rounded)).monospacedDigit()
    }.frame(width: 30, height: 30)
      .accessibilityLabel("Осталось: \(remaining). Завершено: \(completed).")
  }
}
struct WidgetTaskRow: View {
  let task: TaskRecord
  let entry: PlannerWidgetEntry
  var showTag = false
  var compact = false
  private var tag: TagRecord? { entry.snapshot?.tags.first { task.tagIDs.contains($0.id) } }
  private var color: Color { Color(widgetHex: tag?.color) }
  var body: some View {
    HStack(alignment: .center, spacing: 9) {
      Button(intent: CompleteWidgetTaskIntent(taskID: task.id, sourceKey: entry.snapshot?.sourceKey ?? "")) {
        Image(systemName: "circle").font(.system(size: 20, weight: .light)).foregroundStyle(color)
          .frame(width: 24, height: 28).contentShape(Rectangle())
      }.buttonStyle(.plain).accessibilityLabel("Завершить: " + task.title)
      WidgetLink(destination: WidgetAgenda.taskURL(task.id)) {
        VStack(alignment: .leading, spacing: 3) {
          Text(task.title).font(.system(size: compact ? 12 : 13, weight: .medium)).foregroundStyle(.primary).lineLimit(1)
          if showTag, let tag {
            Text("#" + tag.name).font(.system(size: 10, weight: .medium)).foregroundStyle(color).lineLimit(1)
          }
        }.frame(maxWidth: .infinity, alignment: .leading)
      }
      if let date = task.plannedAt ?? task.deadlineAt {
        Text(date, style: .time).font(.system(size: 10, weight: .medium)).monospacedDigit()
          .foregroundStyle(WidgetAgenda.isOverdue(task, now: entry.date) ? Color.red : color)
      } else if WidgetAgenda.isOverdue(task, now: entry.date) {
        Image(systemName: "exclamationmark.circle.fill").font(.caption2).foregroundStyle(.red)
          .accessibilityLabel("Просрочено")
      }
    }
  }
}

// ImageRenderer cannot draw the AppKit-backed Link host. Snapshot tests render
// the identical label tree; real widgets retain native Link navigation.
private struct WidgetPreviewRenderingKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
  var widgetPreviewRendering: Bool {
    get { self[WidgetPreviewRenderingKey.self] }
    set { self[WidgetPreviewRenderingKey.self] = newValue }
  }
}
struct WidgetLink<Label: View>: View {
  let destination: URL
  private let label: Label
  @Environment(\.widgetPreviewRendering) private var renderingPreview
  init(destination: URL, @ViewBuilder label: () -> Label) { self.destination = destination; self.label = label() }
  var body: some View {
    if renderingPreview { label }
    else { Link(destination: destination) { label } }
  }
}
