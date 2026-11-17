import CoreFoundation
import Foundation
import LockedInData

@MainActor final class WidgetCommandObserver {
  private let changed: () -> Void
  init(changed: @escaping () -> Void) {
    self.changed = changed
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque(), { _, pointer, _, _, _ in
        guard let pointer else { return }
        let observer = Unmanaged<WidgetCommandObserver>.fromOpaque(pointer).takeUnretainedValue()
        Task { @MainActor in observer.changed() }
      }, WidgetStore.changeNotification as CFString, nil, .deliverImmediately)
  }
  deinit {
    CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(),
      Unmanaged.passUnretained(self).toOpaque())
  }
}
