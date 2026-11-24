import LockedInData
import LockedInDomain
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BugReportView: View {
  var model: AppModel
  @Environment(\.dismiss) private var dismiss
  @State private var id = UUID()
  @State private var description = ""
  @State private var screenshot: Data?
  @State private var message: String?
  @State private var sending = false
  @State private var importing = false
  @State private var submitted = false
  @State private var filesOpen = false
  @State private var photosOpen = false
  @State private var photo: PhotosPickerItem?
  private var busy: Bool { sending || importing }
  private var canSubmit: Bool { !busy && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && description.unicodeScalars.count <= 6000 }
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          if submitted {
            VStack(spacing: 14) {
              Image(systemName: "checkmark.circle.fill").font(.system(size: 42)).foregroundStyle(Color.accent)
              Text("Спасибо за помощь!").font(.title2.bold())
              Text("Баг-репорт сохранён. Разберёмся.").font(.callout).foregroundStyle(.secondary)
              Button("Готово") { dismiss() }.buttonStyle(.borderedProminent)
            }.frame(maxWidth: .infinity).padding(.vertical, 60)
          } else {
            HStack(spacing: 12) {
              Image(systemName: "ladybug").font(.title2).foregroundStyle(Color.accent)
                .frame(width: 42, height: 42).background(Color.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
              Text("Расскажи, что пошло не так. Скриншот можно добавить по желанию.")
                .font(.callout).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
              Text("Что произошло?").font(.subheadline.weight(.semibold))
              ZStack(alignment: .topLeading) {
                if description.isEmpty {
                  Text("Что ты делал и что получилось вместо ожидаемого?")
                    .font(.body).foregroundStyle(.tertiary).padding(.horizontal, 5).padding(.vertical, 8).allowsHitTesting(false)
                }
                TextEditor(text: $description).font(.body).scrollContentBackground(.hidden)
                  .frame(minHeight: 124).accessibilityLabel("Описание ошибки")
                  #if os(macOS)
                  .onPasteCommand(of: [.image, .fileURL], perform: attach)
                  #endif
              }.padding(10).background(Color.mutedSurface, in: RoundedRectangle(cornerRadius: 14))
              if description.unicodeScalars.count > 6000 { Text("Описание должно быть не длиннее 6000 символов.").font(.caption).foregroundStyle(.red) }
            }
            VStack(alignment: .leading, spacing: 10) {
              HStack {
                Text("Скриншот").font(.subheadline.weight(.semibold))
                Text("необязательно").font(.caption).foregroundStyle(.secondary)
                Spacer()
                if importing { ProgressView().controlSize(.small) }
              }
              if let screenshot {
                preview(screenshot).resizable().scaledToFit().frame(maxWidth: .infinity, maxHeight: 170)
                  .background(Color.mutedSurface, in: RoundedRectangle(cornerRadius: 12)).clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(alignment: .topTrailing) {
                    Button { self.screenshot = nil } label: {
                      Image(systemName: "xmark").font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 28)
                        .background(.regularMaterial, in: Circle())
                    }.buttonStyle(.plain).padding(6).accessibilityLabel("Убрать скриншот")
                  }
              }
              HStack(spacing: 8) {
                Button { filesOpen = true } label: { Label("Файлы", systemImage: "folder") }
                Button { photosOpen = true } label: { Label("Фото", systemImage: "photo") }
                PasteButton(supportedContentTypes: [.image, .fileURL]) { providers in attach(providers) }
                  .labelStyle(.titleAndIcon)
              }.buttonStyle(.bordered).controlSize(.small).disabled(busy)
            }
            EditorFooter(message: message)
          }
        }.padding(22).disabled(busy)
      }.navigationTitle("Сообщить об ошибке")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Закрыть") { dismiss() }.disabled(busy) }
          ToolbarItem(placement: .confirmationAction) {
            if !submitted {
              Button(sending ? "Отправка…" : "Отправить") { Task { await submit() } }
                .disabled(!canSubmit).keyboardShortcut(.defaultAction)
            }
          }
        }
    }
    #if os(macOS)
    .frame(width: 470, height: 540)
    #endif
    .interactiveDismissDisabled(busy)
    .dismissOnOutsideClick(enabled: !busy && !filesOpen && !photosOpen)
    .background {
      AppShortcutHandler(priority: 1000, enabled: !filesOpen && !photosOpen) { shortcut in
        if shortcut == .close { if !busy { dismiss() } }
        else if shortcut == .submit && !busy {
          if submitted { dismiss() } else { Task { await submit() } }
        }
        return true
      }.allowsHitTesting(false)
    }
    .submitOnEnter(enabled: !busy && !filesOpen && !photosOpen) {
      if submitted { dismiss() } else { Task { await submit() } }
    }
    #if os(macOS)
    .onPasteCommand(of: [.image, .fileURL], perform: attach)
    #endif
    .fileImporter(isPresented: $filesOpen, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
      switch result {
      case .success(let urls): if let url = urls.first { importFile(url) }
      case .failure(let error):
        if (error as? CocoaError)?.code != .userCancelled { message = model.friendly(error) }
      }
    }
    .photosPicker(isPresented: $photosOpen, selection: $photo, matching: .images)
    .onChange(of: photo) { _, item in
      guard let item else { return }
      importing = true; message = nil
      Task {
        defer { importing = false; photo = nil }
        do {
          guard let bytes = try await item.loadTransferable(type: Data.self) else { throw RequestFailure.invalidAttachment }
          screenshot = try await Task.detached(priority: .userInitiated) { try BugReportAttachment.image(bytes) }.value
        } catch { message = model.friendly(error) }
      }
    }
  }
  private func preview(_ data: Data) -> Image {
    #if os(macOS)
    Image(nsImage: NSImage(data: data) ?? NSImage())
    #else
    Image(uiImage: UIImage(data: data) ?? UIImage())
    #endif
  }
  private func attach(_ providers: [NSItemProvider]) {
    guard !busy, let provider = providers.first else { return }
    importing = true; message = nil
    Task {
      defer { importing = false }
      do { screenshot = try await BugReportAttachment.provider(provider) }
      catch { message = model.friendly(error) }
    }
  }
  private func importFile(_ url: URL) {
    guard !busy else { return }
    importing = true; message = nil
    Task {
      defer { importing = false }
      do { screenshot = try await Task.detached(priority: .userInitiated) { try BugReportAttachment.file(url) }.value }
      catch { message = model.friendly(error) }
    }
  }
  private func submit() async {
    guard canSubmit else { return }
    sending = true; message = nil
    defer { sending = false }
    do {
      try await model.submitBugReport(id: id, description: description.trimmingCharacters(in: .whitespacesAndNewlines), screenshot: screenshot)
      submitted = true
    } catch { message = model.friendly(error) }
  }
}
