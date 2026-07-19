import Foundation
import SwiftData

nonisolated struct TaskRecurrenceRule: Codable, Hashable {
    var frequency: RecurrenceFrequency = .weekly
    var interval = 1
    var customUnit: RecurrenceUnit = .week
    var weekdays: Set<Int> = []
    var end: RecurrenceEnd = .never
    var excludedDayIdentifiers: Set<String>? = nil

    func occurrenceDates(
        starting startDate: Date,
        calendar: Calendar = .current,
        maximumCount: Int = 500,
        rollingHorizon: Date? = nil
    ) -> [Date] {
        let start = calendar.startOfDay(for: startDate)
        let countLimit: Int
        let endDate: Date?

        switch end {
        case .never:
            countLimit = maximumCount
            endDate = rollingHorizon ?? calendar.date(byAdding: .day, value: 90, to: start)
        case .onDate(let date):
            countLimit = maximumCount
            endDate = calendar.startOfDay(for: date)
        case .afterCount(let count):
            countLimit = min(max(count, 1), maximumCount)
            endDate = nil
        }

        var dates: [Date] = []
        var matchedOccurrenceCount = 0
        var candidate = start
        let hardStop = calendar.date(byAdding: .year, value: 20, to: start) ?? start

        while dates.count < countLimit,
              matchedOccurrenceCount < countLimit,
              candidate <= hardStop {
            if let endDate, candidate > endDate { break }
            let dayIdentifier = PlanoraCalendarDay(date: candidate, calendar: calendar).identifier
            if matches(candidate, anchor: start, calendar: calendar) {
                matchedOccurrenceCount += 1
                if !(excludedDayIdentifiers ?? []).contains(dayIdentifier) {
                    dates.append(candidate)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: candidate) else { break }
            candidate = next
        }

        return dates
    }

    private func matches(_ date: Date, anchor: Date, calendar: Calendar) -> Bool {
        let safeInterval = max(interval, 1)

        switch frequency {
        case .daily:
            let days = calendar.dateComponents([.day], from: anchor, to: date).day ?? 0
            return days >= 0 && days.isMultiple(of: safeInterval)
        case .weekly, .biweekly:
            let selectedWeekdays = weekdays.isEmpty ? [calendar.component(.weekday, from: anchor)] : weekdays
            let weeks = weekDistance(from: anchor, to: date, calendar: calendar)
            let weekInterval = frequency == .biweekly ? 2 : safeInterval
            return weeks >= 0
                && weeks.isMultiple(of: weekInterval)
                && selectedWeekdays.contains(calendar.component(.weekday, from: date))
        case .monthly:
            return matchesMonthly(date, anchor: anchor, interval: safeInterval, calendar: calendar)
        case .custom:
            switch customUnit {
            case .day:
                let days = calendar.dateComponents([.day], from: anchor, to: date).day ?? 0
                return days >= 0 && days.isMultiple(of: safeInterval)
            case .week:
                let weeks = weekDistance(from: anchor, to: date, calendar: calendar)
                let selectedWeekdays = weekdays.isEmpty ? [calendar.component(.weekday, from: anchor)] : weekdays
                return weeks >= 0
                    && weeks.isMultiple(of: safeInterval)
                    && selectedWeekdays.contains(calendar.component(.weekday, from: date))
            case .month:
                return matchesMonthly(date, anchor: anchor, interval: safeInterval, calendar: calendar)
            }
        }
    }

    private func matchesMonthly(_ date: Date, anchor: Date, interval: Int, calendar: Calendar) -> Bool {
        let anchorComponents = calendar.dateComponents([.year, .month], from: anchor)
        let dateComponents = calendar.dateComponents([.year, .month], from: date)
        guard let anchorYear = anchorComponents.year,
              let anchorMonth = anchorComponents.month,
              let dateYear = dateComponents.year,
              let dateMonth = dateComponents.month else { return false }
        let months = (dateYear - anchorYear) * 12 + (dateMonth - anchorMonth)
        guard months >= 0, months.isMultiple(of: interval) else { return false }
        let anchorDay = calendar.component(.day, from: anchor)
        let range = calendar.range(of: .day, in: .month, for: date)
        let expectedDay = min(anchorDay, range?.count ?? anchorDay)
        return calendar.component(.day, from: date) == expectedDay
    }

    private func weekDistance(from anchor: Date, to date: Date, calendar: Calendar) -> Int {
        let anchorWeek = calendar.dateInterval(of: .weekOfYear, for: anchor)?.start ?? anchor
        let dateWeek = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return calendar.dateComponents([.weekOfYear], from: anchorWeek, to: dateWeek).weekOfYear ?? 0
    }

    @MainActor var summary: String {
        switch frequency {
        case .daily:
            interval == 1 ? L("每天", "Every Day") : LF("every_days_format", interval)
        case .weekly:
            interval == 1 ? L("每周", "Every Week") : LF("every_weeks_format", interval)
        case .biweekly:
            L("每两周", "Every Two Weeks")
        case .monthly:
            interval == 1 ? L("每月", "Every Month") : LF("every_months_format", interval)
        case .custom:
            LF("custom_recurrence_format", interval, customUnit.title)
        }
    }
}

nonisolated enum RecurrenceFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case weekly
    case biweekly
    case monthly
    case custom

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .daily: L("每天", "Daily")
        case .weekly: L("每周", "Weekly")
        case .biweekly: L("每两周", "Every Two Weeks")
        case .monthly: L("每月", "Monthly")
        case .custom: L("自定义", "Custom")
        }
    }
}

nonisolated enum RecurrenceUnit: String, Codable, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    @MainActor var title: String {
        switch self {
        case .day: L("天", "days")
        case .week: L("周", "weeks")
        case .month: L("月", "months")
        }
    }
}

nonisolated enum RecurrenceEnd: Codable, Hashable {
    case never
    case onDate(Date)
    case afterCount(Int)
}

nonisolated enum RecurrenceEditScope: Equatable {
    case occurrence
    case future
    case entireSeries
}

@MainActor
enum RecurringTaskEngine {
    static func excludeOccurrence(_ occurrence: PlanoraTask, from seriesTasks: [PlanoraTask]) {
        guard let date = occurrence.deadline else { return }
        let identifier = occurrence.deadlineDayIdentifier
            ?? PlanoraCalendarDay(date: date).identifier
        for task in seriesTasks {
            guard var rule = task.recurrenceRule else { continue }
            var exclusions = rule.excludedDayIdentifiers ?? []
            exclusions.insert(identifier)
            rule.excludedDayIdentifiers = exclusions
            task.recurrenceRule = rule
        }
    }

    static func includeOccurrence(_ occurrence: PlanoraTask, in seriesTasks: [PlanoraTask]) {
        guard let date = occurrence.deadline else { return }
        let identifier = occurrence.deadlineDayIdentifier
            ?? PlanoraCalendarDay(date: date).identifier
        for task in seriesTasks {
            guard var rule = task.recurrenceRule else { continue }
            var exclusions = rule.excludedDayIdentifiers ?? []
            exclusions.remove(identifier)
            rule.excludedDayIdentifiers = exclusions.isEmpty ? nil : exclusions
            task.recurrenceRule = rule
        }
    }

    static func truncateSeries(before occurrence: PlanoraTask, in seriesTasks: [PlanoraTask]) {
        let retained = seriesTasks.filter { $0.recurrenceSequence < occurrence.recurrenceSequence }
        guard let lastDate = retained.compactMap(\.deadline).max() else { return }

        for task in retained {
            guard var rule = task.recurrenceRule else { continue }
            rule.end = .onDate(lastDate)
            task.recurrenceRule = rule
        }
    }

    static func restoreSeriesRule(from occurrence: PlanoraTask, in seriesTasks: [PlanoraTask]) {
        guard let restoredRule = occurrence.recurrenceRule else { return }
        for task in seriesTasks {
            task.recurrenceRule = restoredRule
        }
    }

    static func splitFutureSeries(tasks: [PlanoraTask], from occurrence: PlanoraTask) {
        let future = tasks
            .filter { $0.recurrenceSequence >= occurrence.recurrenceSequence }
            .sorted {
                ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture)
            }
        guard !future.isEmpty else { return }

        let newSeriesID = UUID()
        for (sequence, task) in future.enumerated() {
            task.recurrenceSeriesID = newSeriesID
            task.recurrenceSequence = sequence
        }
    }

    static func materializeSeries(from seed: PlanoraTask, in modelContext: ModelContext) -> [PlanoraTask] {
        guard let rule = seed.recurrenceRule,
              let seriesID = seed.recurrenceSeriesID,
              let startDate = seed.deadline else { return [seed] }

        let dates = rule.occurrenceDates(starting: startDate)
        seed.recurrenceSequence = 0
        seed.recurrenceOccurrenceDate = startDate
        var created = [seed]

        for (sequence, date) in dates.dropFirst().enumerated() {
            let occurrence = copy(
                seed,
                date: date,
                seriesID: seriesID,
                sequence: sequence + 1,
                rule: rule
            )
            modelContext.insert(occurrence)
            created.append(occurrence)
        }

        return created
    }

    static func regenerateFuture(
        from seed: PlanoraTask,
        deleting existingFuture: [PlanoraTask],
        in modelContext: ModelContext
    ) -> [PlanoraTask] {
        for task in existingFuture where task.id != seed.id {
            modelContext.delete(task)
        }

        guard let rule = seed.recurrenceRule,
              let seriesID = seed.recurrenceSeriesID,
              let startDate = seed.deadline else { return [seed] }

        let baseSequence = seed.recurrenceSequence
        let dates = rule.occurrenceDates(starting: startDate)
        var created = [seed]
        for (offset, date) in dates.dropFirst().enumerated() {
            let occurrence = copy(
                seed,
                date: date,
                seriesID: seriesID,
                sequence: baseSequence + offset + 1,
                rule: rule
            )
            modelContext.insert(occurrence)
            created.append(occurrence)
        }
        return created
    }

    @discardableResult
    static func ensureRollingSeries(tasks: [PlanoraTask], in modelContext: ModelContext) -> Bool {
        let series = Dictionary(grouping: tasks.compactMap { task -> (UUID, PlanoraTask)? in
            guard let seriesID = task.recurrenceSeriesID, task.recurrenceRule?.end == .never else { return nil }
            return (seriesID, task)
        }, by: { $0.0 })
        var didCreateOccurrences = false

        for (_, entries) in series {
            let instances = entries.map(\.1)
            guard let latest = instances.max(by: { $0.recurrenceSequence < $1.recurrenceSequence }),
                  let latestDate = latest.deadline,
                  let rule = latest.recurrenceRule,
                  let seriesID = latest.recurrenceSeriesID,
                  let horizon = Calendar.current.date(byAdding: .day, value: 90, to: Date()),
                  latestDate < horizon else { continue }

            let dates = rule.occurrenceDates(starting: latestDate, rollingHorizon: horizon)
            for (offset, date) in dates.dropFirst().enumerated() {
                let occurrence = copy(
                    latest,
                    date: date,
                    seriesID: seriesID,
                    sequence: latest.recurrenceSequence + offset + 1,
                    rule: rule
                )
                modelContext.insert(occurrence)
                didCreateOccurrences = true
            }
        }
        if didCreateOccurrences {
            try? modelContext.save()
        }
        return didCreateOccurrences
    }

    private static func copy(
        _ source: PlanoraTask,
        date: Date,
        seriesID: UUID,
        sequence: Int,
        rule: TaskRecurrenceRule
    ) -> PlanoraTask {
        let progressState: ProgressState = source.progressState.kind == .percentage
            ? .percentage(0)
            : .stage(source.type.defaultStage)
        let occurrence = PlanoraTask(
            title: source.title,
            subject: source.subject,
            type: source.type,
            deadline: date,
            hasDeadline: true,
            tracksProgress: source.tracksProgress,
            progressState: progressState,
            notes: source.notes,
            createdDate: Date(),
            importance: source.importance,
            plannedDate: shiftedPlannedDate(for: source, occurrenceDate: date)
        )
        occurrence.recurrenceRule = rule
        occurrence.recurrenceSeriesID = seriesID
        occurrence.recurrenceSequence = sequence
        occurrence.recurrenceOccurrenceDate = date
        occurrence.reminders = source.reminders.filter(\.isRelativeToDeadline)
        return occurrence
    }

    private static func shiftedPlannedDate(for source: PlanoraTask, occurrenceDate: Date) -> Date? {
        guard let plannedDate = source.plannedDate,
              let sourceDeadline = source.deadline else { return nil }
        return occurrenceDate.addingTimeInterval(plannedDate.timeIntervalSince(sourceDeadline))
    }
}
