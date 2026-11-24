import LockedInData
#if os(macOS)
  import AppKit
  import LockedInDomain
  import SwiftUI

  @MainActor
  final class MacReminderPresenter {
    private var windows: [UUID: NSPanel] = [:]
    private var dismissals: [UUID: Task<Void, Never>] = [:]
    private enum PauseReason { case hover, drag, action }
    private var pauses: [UUID: Set<PauseReason>] = [:]
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
      panel.title = "Напоминание TrackIt"
      panel.isOpaque = false
      panel.backgroundColor = .clear
      panel.hasShadow = false
      panel.level = .floating
      panel.hidesOnDeactivate = false
      panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
      let selected = tags.filter { task.tagIDs.contains($0.id) }
      panel.dismissRequested = { [weak self] in self?.dismiss(task.id) }
      panel.dragging = { [weak self] value in self?.pause(task.id, reason: .drag, active: value) }
      panel.contentView = NSHostingView(
        rootView: ReminderToast(
          task: task, tags: selected, complete: complete, snooze: snooze,
          dismiss: { [weak self] in self?.dismiss(task.id) },
          hover: { [weak self] value in self?.pause(task.id, reason: .hover, active: value) },
          working: { [weak self] value in self?.pause(task.id, reason: .action, active: value) },
          move: { [weak panel] offset in panel?.dragMouse(by: offset) },
          release: { [weak panel] offset in panel?.releaseMouse(projectedExtra: offset) }
        ).trackItAccent().preferredColorScheme(.dark))
      let occupied = windows.values.map { $0.frame.minY }
      var top = screen.visibleFrame.maxY - 18
      while occupied.contains(where: { abs($0 - (top - 190)) < 195 }) { top -= 198 }
      panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - 368, y: top - 190))
      windows[task.id] = panel
      panel.orderFrontRegardless()
      scheduleDismissal(task.id)
      return true
    }
    func dismiss(_ id: UUID) {
      dismissals.removeValue(forKey: id)?.cancel()
      pauses.removeValue(forKey: id)
      guard let panel = windows.removeValue(forKey: id) else { return }
      panel.ignoresMouseEvents = true
      let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
      NSAnimationContext.runAnimationGroup { context in
        context.duration = reduceMotion ? 0.1 : 0.2
        if !reduceMotion {
          let edge = panel.screen?.visibleFrame.maxX ?? panel.frame.maxX
          panel.animator().setFrameOrigin(NSPoint(x: max(edge + 12, panel.frame.minX + 350), y: panel.frame.minY))
        }
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
    private func pause(_ id: UUID, reason: PauseReason, active: Bool) {
      guard windows[id] != nil else { return }
      if active { pauses[id, default: []].insert(reason) }
      else { pauses[id]?.remove(reason) }
      scheduleDismissal(id)
    }
    private func scheduleDismissal(_ id: UUID) {
      dismissals.removeValue(forKey: id)?.cancel()
      guard pauses[id, default: []].isEmpty else { return }
      dismissals[id] = Task { [weak self] in
        do { try await Task.sleep(for: .seconds(6)) } catch { return }
        self?.dismiss(id)
      }
    }
  }
  private final class ReminderPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    var dismissRequested: (() -> Void)?
    var dragging: ((Bool) -> Void)?
    private var restingOrigin: NSPoint?
    private var mouseStartX: CGFloat?
    private var scrollOffset: CGFloat = 0
    private var scrollEnd: Task<Void, Never>?

    func dragMouse(by initialOffset: CGFloat) {
      let pointer = NSEvent.mouseLocation.x
      if mouseStartX == nil { mouseStartX = pointer - initialOffset }
      move(by: pointer - (mouseStartX ?? pointer))
    }
    func releaseMouse(projectedExtra: CGFloat) {
      let distance = mouseStartX.map { NSEvent.mouseLocation.x - $0 } ?? 0
      mouseStartX = nil
      release(projectedOffset: distance + projectedExtra)
    }
    func move(by offset: CGFloat) {
      guard !ignoresMouseEvents else { return }
      if restingOrigin == nil { restingOrigin = frame.origin; dragging?(true) }
      guard let restingOrigin else { return }
      let distance = max(0, offset)
      setFrameOrigin(NSPoint(x: restingOrigin.x + distance, y: restingOrigin.y))
      alphaValue = 1 - min(0.4, distance / 500)
    }
    func release(projectedOffset: CGFloat) {
      scrollEnd?.cancel()
      scrollEnd = nil
      scrollOffset = 0
      guard let origin = restingOrigin else { return }
      restingOrigin = nil
      if frame.minX - origin.x >= 70 || projectedOffset >= 140 {
        dismissRequested?()
      } else {
        NSAnimationContext.runAnimationGroup { context in
          context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0.1 : 0.18
          animator().setFrameOrigin(origin)
          animator().alphaValue = 1
        }
      }
      dragging?(false)
    }
    override func scrollWheel(with event: NSEvent) {
      guard !ignoresMouseEvents, event.momentumPhase.isEmpty else { return }
      guard restingOrigin != nil || abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else {
        super.scrollWheel(with: event)
        return
      }
      scrollOffset += event.scrollingDeltaX
      move(by: scrollOffset)
      if event.phase.contains(.cancelled) {
        move(by: 0)
        release(projectedOffset: 0)
      } else if event.phase.contains(.ended) {
        release(projectedOffset: scrollOffset)
      } else {
        scrollEnd?.cancel()
        scrollEnd = Task { @MainActor [weak self] in
          do { try await Task.sleep(for: .milliseconds(150)) } catch { return }
          guard let self else { return }
          self.release(projectedOffset: self.scrollOffset)
        }
      }
    }
  }
  private struct ReminderToast: View {
    let task: TaskRecord
    let tags: [TagRecord]
    var complete: @MainActor () async throws -> Void
    var snooze: @MainActor () async throws -> Void
    var dismiss: () -> Void
    var hover: (Bool) -> Void
    var working: (Bool) -> Void
    var move: (CGFloat) -> Void
    var release: (CGFloat) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var isWorking = false
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
          }.font(.system(size: 12, weight: .medium)).disabled(isWorking)
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
        .simultaneousGesture(
          DragGesture(minimumDistance: 8)
            .onChanged { value in
              guard !isWorking, abs(value.translation.width) > abs(value.translation.height) else { return }
              move(value.translation.width)
            }
            .onEnded { value in release(value.predictedEndTranslation.width - value.translation.width) }
        )
    }
    private func run(_ action: @escaping @MainActor () async throws -> Void) {
      isWorking = true
      working(true)
      Task { @MainActor in
        defer { isWorking = false; working(false) }
        do {
          try await action()
          dismiss()
        } catch { self.error = UserFacingErrors.message(error) }
      }
    }
  }
#endif
