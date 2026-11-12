#if os(macOS)
  import AppKit
  import LockedInDomain
  import SwiftUI

  @MainActor
  final class MacReminderPresenter {
    private var windows: [UUID: NSPanel] = [:]
    private var dismissals: [UUID: Task<Void, Never>] = [:]
    func show(
      task: TaskRecord, tags: [TagRecord], complete: @escaping @MainActor () async throws -> Void,
      snooze: @escaping @MainActor () async throws -> Void
    ) -> Bool {
      if windows[task.id] != nil { return true }
      guard windows.count < 3,
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
          ?? NSScreen.main
      else { return false }
      let panel = ReminderPanel(
        contentRect: NSRect(x: 0, y: 0, width: 350, height: 190),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
      panel.title = "Напоминание Locked In"
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = false
      panel.level = .floating
      panel.hidesOnDeactivate = false
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
      let selected = tags.filter { task.tagIDs.contains($0.id) }
      panel.contentView = NSHostingView(
        rootView: ReminderToast(
          task: task, tags: selected, complete: complete, snooze: snooze,
          dismiss: { [weak self] in self?.dismiss(task.id) },
          hover: { [weak self] value in self?.scheduleDismissal(task.id, paused: value) }
        ).preferredColorScheme(.dark))
      let occupied = windows.values.map { $0.frame.minY }
      var top = screen.visibleFrame.maxY - 18
      while occupied.contains(where: { abs($0 - (top - 190)) < 195 }) { top -= 198 }
      panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 368, y: top - 190))
      windows[task.id] = panel
      panel.orderFrontRegardless()
      scheduleDismissal(task.id, paused: false)
      return true
    }
    func dismiss(_ id: UUID) {
      dismissals.removeValue(forKey: id)?.cancel()
      guard let panel = windows.removeValue(forKey: id) else { return }
      NSAnimationContext.runAnimationGroup { context in
        context.duration = 0.18
        panel.animator().alphaValue = 0
      } completionHandler: {
        Task { @MainActor in panel.close() }
      }
    }
    func dismissMissing(_ active: Set<UUID>) {
      for id in Array(windows.keys) where !active.contains(id) && id != TaskAlertIDs.test {
        dismiss(id)
      }
    }
    private func scheduleDismissal(_ id: UUID, paused: Bool) {
      dismissals.removeValue(forKey: id)?.cancel()
      guard !paused else { return }
      dismissals[id] = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(14)) } catch { return }
        self?.dismiss(id)
      }
    }
  }
  private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
  }
  private struct ReminderToast: View {
    let task: TaskRecord
    let tags: [TagRecord]
    var complete: @MainActor () async throws -> Void
    var snooze: @MainActor () async throws -> Void
    var dismiss: () -> Void
    var hover: (Bool) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var working = false
    @State private var error: String?
    private var accent: Color { Color(hex: tags.first?.color ?? "#A398FF") }
    var body: some View {
      HStack(spacing: 0) {
        RoundedRectangle(cornerRadius: 3).fill(
          LinearGradient(
            colors: [accent, accent.opacity(0.2)], startPoint: .top, endPoint: .bottom)
        ).frame(width: 3).padding(.vertical, 16)
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: "bell.badge.fill").foregroundStyle(accent).symbolEffect(
              .bounce, value: appeared)
            Text("LOCKED IN").font(.system(size: 10, weight: .bold, design: .rounded)).tracking(2)
              .foregroundStyle(.secondary)
            Spacer()
            Text("Сейчас").font(.caption2).foregroundStyle(.tertiary)
            Button(action: dismiss) {
              Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(
                .secondary
              ).padding(5)
            }.buttonStyle(.plain).accessibilityLabel("Закрыть уведомление")
          }
          Text(task.title).font(.system(size: 15, weight: .semibold, design: .rounded)).lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
          if !tags.isEmpty {
            Text(tags.map { "#" + $0.name }.joined(separator: "  ")).font(.caption).foregroundStyle(
              accent
            ).lineLimit(1)
          }
          Spacer(minLength: 0)
          if let error { Text(error).font(.caption2).foregroundStyle(.orange).lineLimit(2) }
          HStack(spacing: 10) {
            Button {
              run(complete)
            } label: {
              Label("Готово", systemImage: "checkmark").frame(maxWidth: .infinity).padding(
                .vertical, 7)
            }
            .buttonStyle(.plain).background(
              accent.opacity(0.2), in: RoundedRectangle(cornerRadius: 11)
            ).foregroundStyle(accent)
            Button {
              run(snooze)
            } label: {
              Label("Через 5 мин", systemImage: "clock.arrow.circlepath").frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain).background(
              .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 11)
            ).foregroundStyle(.secondary)
          }.font(.system(size: 12, weight: .medium)).disabled(working)
        }.padding(14)
      }.padding(.leading, 10).frame(width: 328, height: 164)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12)) }
        .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
        .offset(x: appeared ? 0 : 34).scaleEffect(appeared ? 1 : 0.96, anchor: .trailing).opacity(
          appeared ? 1 : 0
        )
        .frame(width: 350, height: 190)
        .onAppear {
          withAnimation(
            reduceMotion ? .linear(duration: 0.1) : .spring(response: 0.48, dampingFraction: 0.8)
          ) { appeared = true }
        }
        .onHover(perform: hover)
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
      working = true
      Task { @MainActor in
        defer { working = false }
        do {
          try await action()
          dismiss()
        } catch { self.error = error.localizedDescription }
      }
    }
  }
#endif
