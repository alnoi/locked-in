import SwiftUI

struct PendingSyncBadge: View {
  var pending: Bool
  var body: some View {
    if pending {
      Image(systemName: "flag.fill").font(.system(size: 10)).foregroundStyle(.red)
        .accessibilityLabel("Сохранено на устройстве, ожидает синхронизации")
        .help("Сохранено на устройстве. Ещё не отправлено на сервер.")
    }
  }
}
