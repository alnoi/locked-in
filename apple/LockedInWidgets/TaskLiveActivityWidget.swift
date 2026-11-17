#if os(iOS)
import ActivityKit
import LockedInActivity
import SwiftUI
import WidgetKit

struct TaskLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TaskActivityAttributes.self) { context in
      HStack(spacing: 14) {
        Image(systemName: "scope").font(.title).foregroundStyle(tint(context.state.colorHex))
        VStack(alignment: .leading, spacing: 5) {
          Text(context.isStale ? "Пора начинать" : "Следующая задача").font(.caption)
            .foregroundStyle(.secondary)
          Text(context.state.title).font(.headline).lineLimit(2)
          if !context.state.tagNames.isEmpty {
            Text(context.state.tagNames.map { "#" + $0 }.joined(separator: "  ")).font(.caption)
              .foregroundStyle(tint(context.state.colorHex)).lineLimit(1)
          }
        }
        Spacer()
        countdown(context.state.eventDate).font(.title3.monospacedDigit().bold()).frame(width: 80)
      }.padding(18).activityBackgroundTint(.black.opacity(0.9)).activitySystemActionForegroundColor(
        .white
      )
      .widgetURL(taskURL(context.attributes.taskID))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label("TrackIt", systemImage: "scope").font(.caption.bold()).foregroundStyle(
            tint(context.state.colorHex))
        }
        DynamicIslandExpandedRegion(.trailing) {
          countdown(context.state.eventDate).font(.headline.monospacedDigit())
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 7) {
            Text(context.state.title).font(.headline).lineLimit(2)
            HStack {
              Text(context.isStale ? "Пора начинать" : "До начала").foregroundStyle(.secondary)
              Spacer()
              if let tag = context.state.tagNames.first {
                Text("#" + tag).foregroundStyle(tint(context.state.colorHex))
              }
            }.font(.caption)
          }.padding(.vertical, 4)
        }
      } compactLeading: {
        Image(systemName: "scope").foregroundStyle(tint(context.state.colorHex))
      } compactTrailing: {
        countdown(context.state.eventDate).monospacedDigit().frame(width: 52)
      } minimal: {
        Image(systemName: "scope").foregroundStyle(tint(context.state.colorHex))
      }.keylineTint(tint(context.state.colorHex)).widgetURL(taskURL(context.attributes.taskID))
    }
  }
  @ViewBuilder private func countdown(_ date: Date) -> some View {
    if date > .now {
      Text(timerInterval: Date.now...date, countsDown: true).multilineTextAlignment(.trailing)
    } else {
      Image(systemName: "bell.fill").foregroundStyle(.purple)
    }
  }
  private func taskURL(_ id: UUID) -> URL { URL(string: "lockedin://task/" + id.uuidString)! }
  private func tint(_ hex: String) -> Color {
    let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0xA398FF
    return Color(
      red: Double((value >> 16) & 255) / 255, green: Double((value >> 8) & 255) / 255,
      blue: Double(value & 255) / 255)
  }
}

#endif
