import LockedInDomain
import SwiftUI

struct TagsScreen: View {
  @Bindable var model: AppModel
  var select: (UUID) -> Void
  @State private var editor: TagPresentation?
  private var taskCounts: [UUID: Int] {
    var result: [UUID: Int] = [:]
    for task in model.snapshot.tasks where !task.completed {
      for id in task.tagIDs { result[id, default: 0] += 1 }
    }
    return result
  }
  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(spacing: 16) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Маленькие метки. Больше порядка.").font(.title2.bold())
          Text("Группируй задачи и создавай доски с фильтрами.").font(.callout).foregroundStyle(.secondary)
        }
        Spacer(minLength: 0)
        Button { editor = TagPresentation() } label: { Label("Новый тег", systemImage: "plus") }
          .buttonStyle(.borderedProminent).disabled(!model.canEditCollections)
      }.padding([.horizontal, .top], 24)
      if model.snapshot.tags.isEmpty {
        EmptyState(symbol: "number", title: "У всего будет своя метка",
          message: "Создай первый тег: например, срочно, дом или backend.")
      } else {
        let counts = taskCounts
        ScrollView {
          LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 220), spacing: 10)],
            alignment: .leading, spacing: 10) {
            ForEach(model.snapshot.tags.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }) { tag in
              tile(tag, count: counts[tag.id, default: 0])
            }
          }.padding(.horizontal, 24).padding(.bottom, 24).padding(.top, 2)
        }
      }
    }.sheet(item: $editor) { TagEditor(model: model, presentation: $0).bugReportAccess(model: model, reserveSpace: true) }
  }
  private func tile(_ tag: TagRecord, count: Int) -> some View {
    let tint = Color(hex: tag.color)
    return HStack(spacing: 0) {
      Button { select(tag.id) } label: {
        HStack(spacing: 10) {
          Image(systemName: "number").font(.system(size: 17, weight: .semibold))
            .foregroundStyle(tint).frame(width: 32, height: 34)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
          VStack(alignment: .leading, spacing: 5) {
            Text(tag.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            Label("\(count)", systemImage: "checklist").font(.system(size: 11))
              .foregroundStyle(.secondary).accessibilityLabel("Активных задач: \(count)")
          }
          Spacer(minLength: 0)
        }.padding(.leading, 12).padding(.vertical, 12)
          .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
      }.buttonStyle(.plain).help(tag.name)
      Button { editor = TagPresentation(id: tag.id, name: tag.name, color: tag.color ?? "#6558E8") } label: {
        Image(systemName: "pencil").font(.system(size: 11)).foregroundStyle(.secondary)
          .frame(width: 30, height: 44).contentShape(Rectangle())
      }.buttonStyle(.plain).padding(.trailing, 4).accessibilityLabel("Изменить тег " + tag.name)
    }.background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
      .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(tint.opacity(0.16)))
  }
}
