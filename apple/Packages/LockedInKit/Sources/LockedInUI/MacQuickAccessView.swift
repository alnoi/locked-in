#if os(macOS)
import AppKit
import LockedInDomain
import SwiftUI

public struct MacQuickAccessView: View {
  @Bindable private var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var title = ""
  @State private var saving = false
  @State private var message: String?
  @State private var saved = false
  @FocusState private var focused: Bool
  public init(model: AppModel) { self.model = model }
  public var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Image(systemName: "scope").foregroundStyle(Color.accentColor)
        Text("TrackIt").font(.headline)
        Spacer()
        Button { open("lockedin://today") } label: { Image(systemName: "arrow.up.right.square") }
          .buttonStyle(.plain).help("Открыть TrackIt")
      }
      if model.needsAuthentication {
        Text("Войди в TrackIt, чтобы добавлять задачи.").foregroundStyle(.secondary)
        Button("Открыть TrackIt") { open("lockedin://today") }
      } else {
        VStack(alignment: .leading, spacing: 6) {
          TextField("Что нужно сделать?", text: $title, axis: .vertical)
            .textFieldStyle(.plain).lineLimit(1...5).font(.system(size: 15))
            .focused($focused).onSubmit(save)
          HStack {
            Text("Общая доска · Входящие").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button(action: save) {
              Image(systemName: saving ? "ellipsis" : "arrow.up").font(.system(size: 12, weight: .bold))
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: Circle()).foregroundStyle(.white)
            }.buttonStyle(.plain).disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving || !model.canEdit)
          }
        }.padding(10).background(.primary.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
        if let message {
          Label(message, systemImage: saved ? "checkmark.circle.fill" : "exclamationmark.circle")
            .font(.caption).foregroundStyle(saved ? Color.green : Color.red)
        }
        TimelineView(.periodic(from: .now, by: 60)) { context in
          let tasks = WidgetAgenda.today(model.snapshot.tasks, now: context.date)
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("Сегодня").font(.subheadline.weight(.semibold))
              Spacer()
              Text("\(tasks.count)").font(.caption).foregroundStyle(.secondary)
            }
            if tasks.isEmpty {
              Text("На сегодня всё свободно").font(.caption).foregroundStyle(.secondary)
            } else {
              ScrollView(.vertical) {
                LazyVStack(spacing: 4) {
                  ForEach(tasks) { task in
                    Button { open(WidgetAgenda.taskURL(task.id).absoluteString) } label: {
                      HStack(spacing: 10) {
                        Text(task.plannedAt ?? .now, style: .time)
                          .font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 43, alignment: .leading)
                        Text(task.title).font(.system(size: 13)).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                      }.frame(height: 36).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                  }
                }
              }.frame(height: min(CGFloat(tasks.count * 36 + (tasks.count - 1) * 4), 76))
            }
          }
        }
        Divider()
        HStack {
          Button("Общая доска") { open("lockedin://board") }
          Spacer()
          Button("Календарь") { open(WidgetAgenda.calendarURL(.now).absoluteString) }
        }.font(.caption).buttonStyle(.plain).foregroundStyle(Color.accentColor)
      }
    }.padding(14).frame(width: 330)
      .task { await model.start(); focused = true }
      .submitOnEnter(enabled: !saving, perform: save)
      .onDisappear { if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { save() } }
      .onChange(of: title) { _, _ in message = nil }
  }
  private func save() {
    let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty, !saving, model.canEdit else { return }
    saving = true
    Task {
      defer { saving = false }
      do {
        try await model.mutate(.task(nil, TaskInput(title: value)))
        title = ""; saved = true
        message = "Добавлено в общую доску"
        dismiss()
      } catch { saved = false; message = model.friendly(error) }
    }
  }
  private func open(_ address: String) {
    guard let url = URL(string: address) else { return }
    dismiss()
    NSWorkspace.shared.open(url)
    NSApplication.shared.activate(ignoringOtherApps: true)
  }
}
#endif
