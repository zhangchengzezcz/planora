import XCTest
import UserNotifications
@testable import planora

@MainActor
final class RecurrenceReminderTests: XCTestCase {
    private var gregorian: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }

    func testMonthlyRecurrenceClampsDay31ToEndOfMonth() throws {
        let start = try date(2027, 1, 31)
        let rule = TaskRecurrenceRule(frequency: .monthly, end: .afterCount(4))
        let dates = rule.occurrenceDates(starting: start, calendar: gregorian)

        XCTAssertEqual(components(dates), [[2027, 1, 31], [2027, 2, 28], [2027, 3, 31], [2027, 4, 30]])
    }

    func testLeapDayRecurrenceClampsAndReturnsToFebruary29() throws {
        let start = try date(2024, 2, 29)
        let rule = TaskRecurrenceRule(
            frequency: .custom,
            interval: 12,
            customUnit: .month,
            end: .afterCount(5)
        )
        let dates = rule.occurrenceDates(starting: start, calendar: gregorian)

        XCTAssertEqual(components(dates), [[2024, 2, 29], [2025, 2, 28], [2026, 2, 28], [2027, 2, 28], [2028, 2, 29]])
    }

    func testDailyRecurrenceKeepsLocalCalendarDayAcrossDST() throws {
        let start = try date(2027, 3, 12)
        let rule = TaskRecurrenceRule(frequency: .daily, end: .afterCount(5))
        let dates = rule.occurrenceDates(starting: start, calendar: gregorian)

        XCTAssertEqual(components(dates), [[2027, 3, 12], [2027, 3, 13], [2027, 3, 14], [2027, 3, 15], [2027, 3, 16]])
        XCTAssertTrue(dates.allSatisfy { gregorian.component(.hour, from: $0) == 0 })
    }

    func testCalendarDayKeepsSameDateAcrossTimeZones() throws {
        var shanghai = Calendar(identifier: .gregorian)
        shanghai.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        var losAngeles = Calendar(identifier: .gregorian)
        losAngeles.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let original = try XCTUnwrap(shanghai.date(from: DateComponents(year: 2027, month: 9, day: 10)))
        let day = PlanoraCalendarDay(date: original, calendar: shanghai)
        let reconstructed = try XCTUnwrap(day.date(calendar: losAngeles))
        let components = losAngeles.dateComponents([.year, .month, .day], from: reconstructed)

        XCTAssertEqual(day.identifier, "2027-09-10")
        XCTAssertEqual([components.year, components.month, components.day], [2027, 9, 10])
    }

    func testSelectedWeekdaysAndBiweeklyInterval() throws {
        let start = try date(2027, 7, 5)
        let rule = TaskRecurrenceRule(
            frequency: .biweekly,
            weekdays: [2, 4],
            end: .afterCount(6)
        )
        let dates = rule.occurrenceDates(starting: start, calendar: gregorian)

        XCTAssertEqual(components(dates), [[2027, 7, 5], [2027, 7, 7], [2027, 7, 19], [2027, 7, 21], [2027, 8, 2], [2027, 8, 4]])
    }

    func testNeverEndingRuleUsesBoundedRollingHorizon() throws {
        let start = try date(2027, 1, 1)
        let rule = TaskRecurrenceRule(frequency: .daily, end: .never)
        let dates = rule.occurrenceDates(starting: start, calendar: gregorian)

        XCTAssertFalse(dates.isEmpty)
        XCTAssertLessThanOrEqual(dates.count, 91)
        XCTAssertLessThanOrEqual(dates.count, 500)
    }

    func testExcludedOccurrenceIsNotRegenerated() throws {
        let start = try date(2027, 1, 1)
        let excluded = try date(2027, 1, 3)
        let identifier = PlanoraCalendarDay(date: excluded, calendar: gregorian).identifier
        let rule = TaskRecurrenceRule(
            frequency: .daily,
            end: .afterCount(5),
            excludedDayIdentifiers: [identifier]
        )
        let dates = rule.occurrenceDates(starting: start, calendar: gregorian)

        XCTAssertFalse(components(dates).contains([2027, 1, 3]))
        XCTAssertEqual(components(dates), [[2027, 1, 1], [2027, 1, 2], [2027, 1, 4], [2027, 1, 5]])
    }

    func testSplittingFutureCreatesIndependentSeriesAndPreservesHistory() throws {
        let seriesID = UUID()
        let tasks = (0..<5).map { index in
            makeTask(
                deadline: gregorian.date(byAdding: .day, value: index, to: Date())!,
                seriesID: seriesID,
                sequence: index,
                completed: index < 2
            )
        }

        RecurringTaskEngine.splitFutureSeries(tasks: Array(tasks.dropFirst(2)), from: tasks[2])

        XCTAssertEqual(tasks[0].recurrenceSeriesID, seriesID)
        XCTAssertEqual(tasks[1].recurrenceSeriesID, seriesID)
        XCTAssertTrue(tasks[0].isCompleted)
        XCTAssertTrue(tasks[1].isCompleted)
        XCTAssertNotEqual(tasks[2].recurrenceSeriesID, seriesID)
        XCTAssertEqual(Set(tasks[2...].compactMap(\.recurrenceSeriesID)).count, 1)
        XCTAssertEqual(tasks[2...].map(\.recurrenceSequence), [0, 1, 2])
    }

    func testDeletingFutureTruncatesSeriesAndUndoRestoresRule() throws {
        let seriesID = UUID()
        let start = try date(2027, 1, 1)
        let tasks = (0..<5).map { index in
            makeTask(
                deadline: gregorian.date(byAdding: .day, value: index, to: start)!,
                seriesID: seriesID,
                sequence: index
            )
        }
        let originalRule = try XCTUnwrap(tasks[2].recurrenceRule)

        RecurringTaskEngine.truncateSeries(before: tasks[2], in: tasks)

        guard case .onDate(let truncatedDate) = tasks[0].recurrenceRule?.end else {
            return XCTFail("The retained series should end at its last remaining occurrence")
        }
        XCTAssertEqual(components([truncatedDate]), [[2027, 1, 2]])

        RecurringTaskEngine.restoreSeriesRule(from: tasks[2], in: tasks)
        XCTAssertEqual(tasks[0].recurrenceRule, originalRule)
    }

    func testReminderCandidatesAreSortedLimitedAndExcludeCompletedTasks() throws {
        let now = Date()
        let first = makeTask(deadline: now.addingTimeInterval(3 * 86_400))
        first.reminders = [
            TaskReminder(timing: .daysBefore(1), hour: 9),
            TaskReminder(timing: .daysBefore(2), hour: 9)
        ]
        let completed = makeTask(deadline: now.addingTimeInterval(2 * 86_400), completed: true)
        completed.reminders = [TaskReminder(timing: .daysBefore(1), hour: 9)]

        let candidates = TaskReminderScheduler.candidates(tasks: [completed, first], now: now, limit: 2)

        XCTAssertEqual(candidates.count, 2)
        XCTAssertTrue(candidates.allSatisfy { $0.task.id == first.id })
        XCTAssertLessThan(candidates[0].fireDate, candidates[1].fireDate)
        XCTAssertEqual(Set(candidates.map { "\($0.task.id)-\($0.reminder.id)" }).count, 2)
    }

    func testTaskSupportsDozensOfMilestonesWithoutLosingOrder() {
        let task = makeTask(deadline: Date().addingTimeInterval(60 * 86_400))
        task.tracksProgress = true
        task.progressState = .stage("Stage 0")
        let milestones = (0..<50).map { AcademicMilestone(title: "Stage \($0)") }
        task.replaceTimeline(with: milestones)

        task.toggleMilestone(id: milestones[25].id)
        XCTAssertEqual(task.timeline.filter(\.isCompleted).count, 26)
        XCTAssertEqual(task.timeline.map(\.title), milestones.map(\.title))

        task.toggleMilestone(id: milestones[10].id)
        XCTAssertEqual(task.timeline.filter(\.isCompleted).count, 10)
    }

    func testReopeningTaskRestoresReminderEligibility() {
        let now = Date()
        let task = makeTask(deadline: now.addingTimeInterval(2 * 86_400), completed: true)
        task.reminders = [TaskReminder(timing: .daysBefore(1), hour: 9)]
        XCTAssertTrue(TaskReminderScheduler.candidates(tasks: [task], now: now).isEmpty)

        task.setCompleted(false)
        XCTAssertEqual(TaskReminderScheduler.candidates(tasks: [task], now: now).count, 1)
    }

    func testRollingNotificationQueueSelectsNearestFortyEight() {
        let now = Date()
        let tasks = (1...100).map { day -> PlanoraTask in
            let task = makeTask(deadline: now.addingTimeInterval(Double(day) * 86_400))
            task.reminders = [TaskReminder(timing: .atDeadline, hour: 9)]
            return task
        }

        let candidates = TaskReminderScheduler.candidates(tasks: tasks, now: now, limit: 48)
        XCTAssertEqual(candidates.count, 48)
        XCTAssertTrue(zip(candidates, candidates.dropFirst()).allSatisfy { pair in
            pair.0.fireDate <= pair.1.fireDate
        })
    }

    func testIdenticalReminderTimesAreDeduplicated() {
        let now = Date()
        let task = makeTask(deadline: now.addingTimeInterval(3 * 86_400))
        task.reminders = [
            TaskReminder(timing: .daysBefore(1), hour: 9),
            TaskReminder(timing: .daysBefore(1), hour: 9)
        ]

        XCTAssertEqual(task.reminders.count, 1)
        XCTAssertEqual(TaskReminderScheduler.candidates(tasks: [task], now: now).count, 1)
    }

    func testSnoozedReminderRemainsOwnedByTaskForCancellation() {
        let taskID = UUID()
        let content = UNMutableNotificationContent()
        content.userInfo = ["taskID": taskID.uuidString]

        let identifier = TaskReminderScheduler.snoozeRequestIdentifier(content: content)
        XCTAssertTrue(identifier.hasPrefix("planora.task.\(taskID.uuidString)."))
        XCTAssertTrue(TaskReminderScheduler.isSnoozeRequest(identifier))
        XCTAssertEqual(TaskReminderScheduler.taskID(fromRequestIdentifier: identifier), taskID)
    }

    private func makeTask(
        deadline: Date,
        seriesID: UUID? = nil,
        sequence: Int = 0,
        completed: Bool = false
    ) -> PlanoraTask {
        let task = PlanoraTask(
            title: "Test",
            subject: "Physics HL",
            type: .assignment,
            deadline: deadline,
            hasDeadline: true,
            tracksProgress: false,
            progressState: .percentage(0),
            notes: "",
            isCompleted: completed,
            completedDate: completed ? Date() : nil
        )
        task.recurrenceRule = TaskRecurrenceRule(frequency: .daily, end: .never)
        task.recurrenceSeriesID = seriesID
        task.recurrenceSequence = sequence
        return task
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        try XCTUnwrap(gregorian.date(from: DateComponents(year: year, month: month, day: day)))
    }

    private func components(_ dates: [Date]) -> [[Int]] {
        dates.map {
            let value = gregorian.dateComponents([.year, .month, .day], from: $0)
            return [value.year!, value.month!, value.day!]
        }
    }
}
