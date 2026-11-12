#if os(macOS)
  import LockedInData
  import SwiftUI

  public struct ReminderAlarmView: View {
    @Bindable private var scheduler: TaskAlertScheduler
    @Environment(\.dismiss) private var dismiss
    public init(scheduler: TaskAlertScheduler) { self.scheduler = scheduler }
    public var body: some View {
      VStack(spacing: 20) {
        Image(systemName: "alarm.fill").font(.system(size: 40)).foregroundStyle(Color.accent)
        Text(scheduler.ringing.first?.title ?? "Будильник остановлен").font(.title2.bold())
          .multilineTextAlignment(.center)
        Button("Остановить") {
          if let task = scheduler.ringing.first { scheduler.stop(task.id) }
        }.buttonStyle(.borderedProminent).controlSize(.large)
      }.padding(32).frame(width: 380, height: 240)
        .onChange(of: scheduler.ringing.isEmpty) { _, empty in if empty { dismiss() } }
        .onDisappear { for task in scheduler.ringing { scheduler.stop(task.id) } }
    }
  }
#endif
