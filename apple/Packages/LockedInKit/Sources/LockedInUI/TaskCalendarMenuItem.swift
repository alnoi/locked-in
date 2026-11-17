import LockedInDomain
import SwiftUI

struct TaskCalendarMenuItem: View {
  @Bindable var model: AppModel
  let task: TaskRecord
  var replan: () -> Void
  var body: some View {
    if WidgetAgenda.needsRescheduling(task) {
      Button("Запланировать заново", systemImage: "calendar.badge.clock", action: replan)
        .disabled(!model.canEdit)
    } else {
      Button(task.plannedAt == nil ? "Запланировать" : "Перейти в календарь",
        systemImage: task.plannedAt == nil ? "calendar.badge.plus" : "calendar") {
        model.openCalendar(task.id)
      }.disabled(task.plannedAt == nil && !model.canEdit)
    }
  }
}
