import Charts
import LockedInDomain
import SwiftUI

struct ProfileStatisticsView: View {
  var tasks: [TaskRecord]
  @State private var period: ProfileStatisticsPeriod = .month
  var body: some View {
    TimelineView(.periodic(from: .now, by: 60)) { context in
      let stats = ProfileStatistics(tasks: tasks, period: period, now: context.date)
      VStack(alignment: .leading, spacing: 20) {
        HStack {
          Text("Твой ритм").font(.system(size: 18, weight: .semibold))
          Spacer()
          Text("Личная статистика").font(.caption).foregroundStyle(.secondary)
        }
        today(stats)
        Picker("Период статистики", selection: $period) {
          Text("Неделя").tag(ProfileStatisticsPeriod.week)
          Text("Месяц").tag(ProfileStatisticsPeriod.month)
          Text("Год").tag(ProfileStatisticsPeriod.year)
        }.pickerStyle(.segmented)
        Text("За последние \(period.days) дней · по дате создания")
          .font(.caption).foregroundStyle(.secondary)
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
          metric("Сделано", value: String(stats.completed), caption: "Всего из \(stats.total)",
            symbol: "checkmark.circle.fill", tint: .mint)
          metric("Просрочено", value: String(stats.overdue), caption: "Пропущен план или дедлайн",
            symbol: "calendar.badge.exclamationmark", tint: stats.overdue > 0 ? .orange : .secondary)
          metric("В среднем за неделю", value: stats.weeklyAverage.formatted(.number.precision(.fractionLength(0...1))),
            caption: "По выбранному периоду", symbol: "chart.bar.fill", tint: .accent)
          metric("В работе", value: String(stats.active), caption: "Ещё не завершено",
            symbol: "circle.dotted", tint: .blue)
        }
        insight(stats)
        creationChart(stats)
        Text("Показатели — по задачам и проектам, созданным за выбранный период; выполнение и просрочки — их текущее состояние. Удалённые не учитываются. Блок «Сегодня» всегда показывает сегодняшний план.")
          .font(.system(size: 10)).foregroundStyle(.tertiary)
      }
    }
  }
  private func metric(_ title: String, value: String, caption: String, symbol: String, tint: Color) -> some View {
    VStack(alignment: .leading, spacing: 7) {
      HStack(spacing: 6) {
        Image(systemName: symbol).foregroundStyle(tint)
        Text(title).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.85)
      }.font(.system(size: 11, weight: .medium))
      Text(value).font(.system(size: 29, weight: .semibold, design: .rounded)).monospacedDigit()
      Text(caption).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(2)
    }.padding(14).frame(maxWidth: .infinity, minHeight: 97, alignment: .leading)
      .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 15))
      .overlay(RoundedRectangle(cornerRadius: 15).strokeBorder(tint.opacity(0.1)))
  }
  private func today(_ stats: ProfileStatistics) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Label("Сегодня", systemImage: "sun.max").font(.system(size: 13, weight: .medium))
        Spacer()
        Text(stats.todayTotal == 0 ? "Без плана" : "\(stats.todayCompleted) / \(stats.todayTotal)")
          .font(.system(size: 12, weight: .medium, design: .rounded)).foregroundStyle(.secondary)
      }
      if stats.todayTotal > 0 {
        ProgressView(value: Double(stats.todayCompleted), total: Double(stats.todayTotal))
          .tint(stats.todayRemaining == 0 ? .mint : Color.accent)
          .accessibilityLabel("Выполнено сегодня")
          .accessibilityValue("\(stats.todayCompleted) из \(stats.todayTotal)")
      } else {
        Text("Запланируй задачу в календаре — здесь появится прогресс дня.")
          .font(.caption).foregroundStyle(.secondary)
      }
    }.padding(15).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 15))
  }
  private func creationChart(_ stats: ProfileStatistics) -> some View {
    VStack(alignment: .leading, spacing: 14) {
      HStack {
        Text("Новые задачи").font(.system(size: 13, weight: .semibold))
        Spacer()
        Text(period == .week ? "По дням" : period == .month ? "По неделям" : "По месяцам").font(.caption).foregroundStyle(.secondary)
      }
      Chart(stats.buckets) { bucket in
        BarMark(x: .value("Начало периода", bucket.start.formatted(period == .year ? .dateTime.month(.abbreviated).year(.twoDigits) : .dateTime.day().month(.abbreviated))),
          y: .value("Создано задач", bucket.created), width: .ratio(0.45))
          .foregroundStyle(Color.accent.gradient).cornerRadius(5)
          .annotation(position: .top) {
            Text(String(bucket.created)).font(.system(size: 11, weight: .medium, design: .rounded))
              .foregroundStyle(.secondary)
          }
          .accessibilityLabel("С \(bucket.start.formatted(date: .abbreviated, time: .omitted))")
          .accessibilityValue("Создано задач: \(bucket.created)")
      }.chartYScale(domain: 0...max(1, (stats.buckets.map(\.created).max() ?? 0) + 1))
        .chartYAxis(.hidden).chartXAxis { AxisMarks { _ in AxisValueLabel() } }
        .frame(height: 112)
    }.padding(16).background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 15))
  }
  private func insight(_ stats: ProfileStatistics) -> some View {
    let hint = hint(stats)
    return HStack(alignment: .top, spacing: 12) {
      Image(systemName: hint.symbol).font(.system(size: 18)).foregroundStyle(Color.accent)
        .frame(width: 32, height: 32).background(Color.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
      VStack(alignment: .leading, spacing: 5) {
        Text(hint.title).font(.system(size: 13, weight: .semibold))
        Text(hint.text).font(.system(size: 12)).foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }.padding(15).frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.accent.opacity(0.045), in: RoundedRectangle(cornerRadius: 15))
  }
  private func hint(_ stats: ProfileStatistics) -> (title: String, text: String, symbol: String) {
    if stats.total == 0 {
      return ("В этом периоде пока тихо", "За выбранный период новых задач нет. Можно посмотреть более длинный период или начать с одного небольшого дела.", "sparkles")
    }
    if stats.todayTotal > 0 && stats.todayRemaining == 0 && stats.overdue == 0 {
      return ("На сегодня — всё", "Все задачи из сегодняшнего плана сделаны. Можно выдохнуть: ты молодец.", "hands.clap")
    }
    if stats.overdue > 0 {
      return ("Разгрузи хвосты", "Загляни в «Просроченные»: выбери, что ещё актуально, и назначь новое время. Необязательно тащить всё в сегодняшний день.", "arrow.trianglehead.clockwise")
    }
    if stats.todayRemaining > 6 {
      return ("План получился плотным", "Выбери 2–3 главных дела на сегодня. Остальным можно дать другое время, чтобы оставить место для пауз.", "leaf")
    }
    if stats.unplanned > 0 && stats.unplanned * 2 > stats.active {
      return ("Дай задачам время", "Большая часть открытых задач пока без планирования. Выбери одну и найди для неё свободный блок в календаре.", "calendar.badge.clock")
    }
    if stats.completed > 0 {
      return ("Хороший ритм", "Среди задач этого периода просрочек нет. Двигайся по одной задаче и оставляй немного свободного времени между делами.", "sparkles")
    }
    return ("Начни с простого", "Выбери небольшую задачу, которую можно закончить сейчас. Первый закрытый пункт поможет разогнаться.", "checkmark.circle")
  }
}
