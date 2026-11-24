import LockedInData
import LockedInDomain
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct TagPresentation: Identifiable {
  var id: UUID = UUID()
  var name = ""
  var color = "#6558E8"
}

struct TagEditor: View {
  @Bindable var model: AppModel
  let presentation: TagPresentation
  @State private var name: String
  @State private var color: String
  @State private var message: String?
  @State private var confirmDelete = false
  @State private var saving = false
  @Environment(\.dismiss) private var dismiss
  private static let colors: [(name: String, hex: String)] = [
    ("Красный", "#EF4444"), ("Коралловый", "#FB7185"), ("Оранжевый", "#F97316"), ("Янтарный", "#F59E0B"),
    ("Жёлтый", "#EAB308"), ("Лаймовый", "#84CC16"), ("Зелёный", "#22C55E"), ("Изумрудный", "#10B981"),
    ("Мятный", "#2DD4BF"), ("Бирюзовый", "#14B8A6"), ("Голубой", "#06B6D4"), ("Небесный", "#38BDF8"),
    ("Синий", "#3B82F6"), ("Индиго", "#6366F1"), ("Фиолетовый", "#6558E8"), ("Лавандовый", "#A78BFA"),
    ("Пурпурный", "#A855F7"), ("Фуксия", "#D946EF"), ("Розовый", "#EC4899"), ("Пудровый", "#F9A8D4"),
    ("Коричневый", "#A87857"), ("Серый", "#64748B"), ("Графитовый", "#71717A"), ("Серебристый", "#A3A3A3"),
  ]
  init(model: AppModel, presentation: TagPresentation) {
    self.model = model
    self.presentation = presentation
    _name = State(initialValue: presentation.name)
    _color = State(initialValue: presentation.color)
  }
  private var exists: Bool { model.snapshot.tags.contains { $0.id == presentation.id } }
  private var customColor: Binding<Color> {
    Binding(get: { Color(hex: color) }, set: { if let hex = Self.hex($0) { color = hex } })
  }
  var body: some View {
    NavigationStack {
      Form {
        Section("Название") {
          TextField("Например, срочно", text: $name).font(.system(size: 16))
        }
        Section("Цвет") {
          LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 8), spacing: 10) {
            ForEach(Self.colors, id: \.hex) { option in
              Button { color = option.hex } label: {
                RoundedRectangle(cornerRadius: 9).fill(Color(hex: option.hex)).frame(height: 32)
                  .overlay {
                    if color.caseInsensitiveCompare(option.hex) == .orderedSame {
                      Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white).shadow(color: .black.opacity(0.5), radius: 1, y: 1)
                    }
                  }
                  .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.primary.opacity(0.1)))
                  .contentShape(RoundedRectangle(cornerRadius: 9))
              }.buttonStyle(.plain).accessibilityLabel(option.name)
                .accessibilityAddTraits(color.caseInsensitiveCompare(option.hex) == .orderedSame ? .isSelected : [])
            }
          }.padding(.vertical, 6)
          HStack {
            ColorPicker("Свой цвет", selection: customColor, supportsOpacity: false)
            Text(color.uppercased()).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
          }
        }
        if exists { Section { Button("Удалить тег", role: .destructive) { confirmDelete = true } } }
        EditorFooter(message: message)
      }.onSubmit { Task { await save() } }.formStyle(.grouped)
        .navigationTitle(exists ? "Изменить тег" : "Новый тег")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Отмена") { dismiss() }.keyboardShortcut(.cancelAction).disabled(saving || model.isMutating)
          }
          ToolbarItem(placement: .confirmationAction) {
            Button("Сохранить") { Task { await save() } }.keyboardShortcut(.defaultAction)
              .disabled(!model.canEditCollections || saving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
        .confirmationDialog("Удалить тег?", isPresented: $confirmDelete, titleVisibility: .visible) {
          Button("Удалить", role: .destructive) {
            Task {
              do { try await model.mutate(.deleteTag(presentation.id)); dismiss() }
              catch { message = UserFacingErrors.message(error) }
            }
          }
        }
    }.interactiveDismissDisabled(saving || model.isMutating || confirmDelete)
        .dismissOnOutsideClick(enabled: !saving && !model.isMutating && !confirmDelete)
        .submitOnEnter(enabled: !saving && !model.isMutating && !confirmDelete) { Task { await save() } }
    #if os(macOS)
    .frame(width: 430, height: 410)
    #endif
  }
  private func save() async {
    guard !saving, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    saving = true
    defer { saving = false }
    do {
      try await model.mutate(.tag(exists ? presentation.id : nil,
        name: name.trimmingCharacters(in: .whitespacesAndNewlines), color: color))
      dismiss()
    } catch { message = UserFacingErrors.message(error) }
  }
  private static func hex(_ value: Color) -> String? {
    #if os(macOS)
    guard let rgb = NSColor(value).usingColorSpace(.sRGB) else { return nil }
    let components = [rgb.redComponent, rgb.greenComponent, rgb.blueComponent]
    #else
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    guard UIColor(value).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
    let components = [red, green, blue]
    #endif
    let bytes = components.map { Int((min(1, max(0, $0)) * 255).rounded()) }
    return String(format: "#%02X%02X%02X", bytes[0], bytes[1], bytes[2])
  }
}
