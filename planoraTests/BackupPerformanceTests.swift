import SwiftData
import XCTest
@testable import planora

@MainActor
final class BackupPerformanceTests: XCTestCase {
    func testIGCSEShowsSingleAssignmentWithMergedIcon() {
        let types = TaskType.availableTypes(for: .igcse, selectedSubjects: ["English"])

        XCTAssertEqual(types.filter { $0 == .assignment }.count, 1)
        XCTAssertEqual(TaskType.assignment.symbol, "doc.richtext.fill")
    }

    func testV8RoundTripPreservesReminderRecurrenceAndPlanningData() throws {
        let task = makeTask(index: 1)
        task.setPlannedDate(Date(timeIntervalSince1970: 1_800_000_000))
        task.reminders = [TaskReminder(timing: .daysBefore(3), hour: 8, minute: 30)]
        task.recurrenceRule = TaskRecurrenceRule(frequency: .weekly, weekdays: [2, 5], end: .afterCount(8))
        task.recurrenceSeriesID = UUID()
        task.recurrenceSequence = 3

        let json = try TaskBackupCodec.json(for: [task])
        let restored = try XCTUnwrap(TaskBackupCodec.tasks(from: json).first)

        XCTAssertEqual(restored.id, task.id)
        XCTAssertEqual(restored.plannedDayIdentifier, task.plannedDayIdentifier)
        XCTAssertEqual(
            restored.plannedDate.map { PlanoraCalendarDay(date: $0).identifier },
            task.plannedDayIdentifier
        )
        XCTAssertEqual(restored.reminders, task.reminders)
        XCTAssertEqual(restored.recurrenceRule, task.recurrenceRule)
        XCTAssertEqual(restored.recurrenceSeriesID, task.recurrenceSeriesID)
        XCTAssertEqual(restored.recurrenceSequence, 3)
    }

    func testOlderBackupVersionsAreRejected() throws {
        let json = try TaskBackupCodec.json(for: [makeTask(index: 1)])
            .replacingOccurrences(of: "\"version\" : 8", with: "\"version\" : 7")

        XCTAssertThrowsError(try TaskBackupCodec.tasks(from: json)) { error in
            guard case TaskBackupError.unsupportedVersion = error else {
                return XCTFail("Expected unsupported version error, got \(error)")
            }
        }
    }

    func testMalformedEmptyAndPartialBackupsDoNotMutateExistingStore() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        context.insert(makeTask(index: 0))
        try context.save()

        for invalid in [
            "{broken",
            "{\"version\":8,\"exportedAt\":\"2026-07-11T00:00:00Z\",\"tasks\":[]}",
            "{\"version\":8,\"exportedAt\":\"2026-07-11T00:00:00Z\",\"tasks\":[{\"subject\":\"Physics\"}]}"
        ] {
            XCTAssertThrowsError(try TaskBackupCodec.tasks(from: invalid))
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 1)
        }
    }

    func testRepeatedImportSkipsDuplicates() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let source = makeTask(index: 2)
        let json = try TaskBackupCodec.json(for: [source])

        let firstPreview = TaskImportPreview(tasks: try TaskBackupCodec.tasks(from: json), duplicateCount: 0)
        _ = try TaskBackupImporter.importTasks(firstPreview, strategy: .skipDuplicates, existingTasks: [], into: context)
        let existing = try context.fetch(FetchDescriptor<PlanoraTask>())
        let secondPreview = TaskImportPreview(tasks: try TaskBackupCodec.tasks(from: json), duplicateCount: 1)
        let result = try TaskBackupImporter.importTasks(secondPreview, strategy: .skipDuplicates, existingTasks: existing, into: context)

        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 1)
    }

    func testRecurringImportDeduplicatesAfterIDsAndSeriesIDsChange() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let dates = [
            Date(timeIntervalSince1970: 1_800_000_000),
            Date(timeIntervalSince1970: 1_800_604_800)
        ]
        let existingSeriesID = UUID()
        let importedSeriesID = UUID()
        let existing = dates.enumerated().map { index, date in
            makeRecurringTask(date: date, seriesID: existingSeriesID, sequence: index)
        }
        for task in existing { context.insert(task) }
        try context.save()

        let imported = dates.enumerated().map { index, date -> PlanoraTask in
            let task = makeRecurringTask(date: date, seriesID: importedSeriesID, sequence: index)
            task.id = UUID()
            task.createdDate = Date(timeIntervalSince1970: 1_900_000_000 + Double(index))
            return task
        }
        let preview = TaskBackupImporter.preview(tasks: imported, existingTasks: existing)
        let result = try TaskBackupImporter.importTasks(
            preview,
            strategy: .skipDuplicates,
            existingTasks: existing,
            into: context
        )

        XCTAssertEqual(preview.duplicateCount, 2)
        XCTAssertEqual(result.importedCount, 0)
        XCTAssertEqual(result.skippedCount, 2)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 2)
    }

    func testRecurringImportKeepsDifferentOccurrenceDates() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let existing = makeRecurringTask(
            date: Date(timeIntervalSince1970: 1_800_000_000),
            seriesID: UUID(),
            sequence: 0
        )
        context.insert(existing)
        try context.save()

        let imported = makeRecurringTask(
            date: Date(timeIntervalSince1970: 1_800_086_400),
            seriesID: UUID(),
            sequence: 0
        )
        let preview = TaskBackupImporter.preview(tasks: [imported], existingTasks: [existing])
        let result = try TaskBackupImporter.importTasks(
            preview,
            strategy: .skipDuplicates,
            existingTasks: [existing],
            into: context
        )

        XCTAssertEqual(preview.duplicateCount, 0)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.skippedCount, 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 2)
    }

    func testRecurringDuplicatesInsideSingleBackupAreSkipped() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        let first = makeRecurringTask(date: date, seriesID: UUID(), sequence: 0)
        let duplicate = makeRecurringTask(date: date, seriesID: UUID(), sequence: 4)
        duplicate.createdDate = Date(timeIntervalSince1970: 1_900_000_000)

        let preview = TaskBackupImporter.preview(tasks: [first, duplicate], existingTasks: [])
        let result = try TaskBackupImporter.importTasks(
            preview,
            strategy: .skipDuplicates,
            existingTasks: [],
            into: context
        )

        XCTAssertEqual(preview.duplicateCount, 1)
        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 1)
    }

    func testRecurringSeriesRoundTripKeepsSeriesIdentity() throws {
        let seriesID = UUID()
        let tasks = (0..<4).map { index -> PlanoraTask in
            let task = makeTask(index: index)
            task.recurrenceRule = TaskRecurrenceRule(frequency: .weekly, end: .afterCount(4))
            task.recurrenceSeriesID = seriesID
            task.recurrenceSequence = index
            return task
        }

        let restored = try TaskBackupCodec.tasks(from: TaskBackupCodec.json(for: tasks))
        XCTAssertEqual(Set(restored.compactMap(\.recurrenceSeriesID)), Set([seriesID]))
        XCTAssertEqual(restored.map(\.recurrenceSequence).sorted(), [0, 1, 2, 3])
    }

    func testAutomaticBackupCanRestoreLatestSnapshot() throws {
        let tasks = [makeTask(index: 10), makeTask(index: 11)]
        AutomaticTaskBackup.save(tasks: tasks)
        let restored = try AutomaticTaskBackup.tasks()

        XCTAssertEqual(restored.map(\.id), tasks.map(\.id))
        XCTAssertEqual(restored.map(\.title), tasks.map(\.title))
    }

    func testImportAsNewRemapsRecurringSeriesIdentity() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let originalSeriesID = UUID()
        let source = (0..<3).map { index -> PlanoraTask in
            let task = makeTask(index: index)
            task.recurrenceRule = TaskRecurrenceRule(frequency: .weekly, end: .afterCount(3))
            task.recurrenceSeriesID = originalSeriesID
            task.recurrenceSequence = index
            return task
        }
        let preview = TaskImportPreview(tasks: source, duplicateCount: 0)
        _ = try TaskBackupImporter.importTasks(preview, strategy: .importAsNew, existingTasks: [], into: context)
        let imported = try context.fetch(FetchDescriptor<PlanoraTask>())

        XCTAssertEqual(imported.count, 3)
        XCTAssertEqual(Set(imported.compactMap(\.recurrenceSeriesID)).count, 1)
        XCTAssertNotEqual(imported.first?.recurrenceSeriesID, originalSeriesID)
        XCTAssertEqual(Set(imported.map(\.id)).count, 3)
    }

    func testTwoThousandTaskSwiftDataAndBackupPerformance() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        let tasks = (0..<2_000).map(makeTask(index:))
        let clock = ContinuousClock()

        let insertionStart = clock.now
        for task in tasks { context.insert(task) }
        try context.save()
        let insertionDuration = insertionStart.duration(to: clock.now)

        let fetchStart = clock.now
        let fetched = try context.fetch(FetchDescriptor<PlanoraTask>())
        let fetchDuration = fetchStart.duration(to: clock.now)

        let backupStart = clock.now
        let json = try TaskBackupCodec.json(for: fetched)
        let backupDuration = backupStart.duration(to: clock.now)

        XCTAssertEqual(fetched.count, 2_000)
        XCTAssertGreaterThan(json.count, 100_000)
        XCTAssertLessThan(insertionDuration, .seconds(5))
        XCTAssertLessThan(fetchDuration, .seconds(2))
        XCTAssertLessThan(backupDuration, .seconds(5))
    }

    func testBackupScalesAtOneHundredFiveHundredAndTwoThousandTasks() throws {
        for count in [100, 500, 2_000] {
            let tasks = (0..<count).map(makeTask(index:))
            let clock = ContinuousClock()
            let start = clock.now
            let json = try TaskBackupCodec.json(for: tasks)
            let restored = try TaskBackupCodec.tasks(from: json)
            let duration = start.duration(to: clock.now)

            XCTAssertEqual(restored.count, count)
            XCTAssertLessThan(duration, .seconds(8), "Backup round trip was too slow for \(count) tasks")
        }
    }

    func testAppearanceSettingsRoundTripPreservesEveryChoice() throws {
        let settings = PlanoraAppearanceSettings(
            displayMode: .dark,
            fontStyle: .monospaced,
            backgroundStyle: .rose,
            accent: .amber,
            usesChineseFont: true
        )

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(PlanoraAppearanceSettings.self, from: data)

        XCTAssertEqual(restored, settings)
    }

    func testAppearanceDefaultsRemainStable() {
        let settings = PlanoraAppearanceSettings.default

        XCTAssertEqual(settings.displayMode, .system)
        XCTAssertEqual(settings.fontStyle, .system)
        XCTAssertEqual(settings.backgroundStyle, .aurora)
        XCTAssertEqual(settings.accent, .blue)
        XCTAssertFalse(settings.usesChineseFont)
    }

    func testAppearanceStoragePersistsSelection() {
        let original = PlanoraAppearanceStorage.load()
        defer { PlanoraAppearanceStorage.save(original) }
        let settings = PlanoraAppearanceSettings(
            displayMode: .light,
            fontStyle: .rounded,
            backgroundStyle: .mint,
            accent: .green
        )

        PlanoraAppearanceStorage.save(settings)

        XCTAssertEqual(PlanoraAppearanceStorage.load(), settings)
    }

    func testPreviousAppearancePayloadDefaultsChineseFontSwitchToOff() throws {
        let data = Data(#"{"displayMode":"dark","fontStyle":"serif","backgroundStyle":"rose","accent":"pink"}"#.utf8)
        let settings = try JSONDecoder().decode(PlanoraAppearanceSettings.self, from: data)

        XCTAssertEqual(settings.displayMode, .dark)
        XCTAssertEqual(settings.fontStyle, .serif)
        XCTAssertEqual(settings.backgroundStyle, .rose)
        XCTAssertEqual(settings.accent, .pink)
        XCTAssertFalse(settings.usesChineseFont)
    }

    func testTaskDisplaySettingsRoundTripPreservesEveryChoice() throws {
        let settings = PlanoraTaskDisplaySettings(
            density: .compact,
            sortOrder: .title,
            showsCompletedTasks: false,
            showsProgressPercentage: false,
            showsNotes: false
        )

        let data = try JSONEncoder().encode(settings)
        let restored = try JSONDecoder().decode(PlanoraTaskDisplaySettings.self, from: data)

        XCTAssertEqual(restored, settings)
    }

    func testTaskDisplayDefaultsRemainStable() {
        let settings = PlanoraTaskDisplaySettings.default

        XCTAssertEqual(settings.density, .comfortable)
        XCTAssertEqual(settings.sortOrder, .smart)
        XCTAssertTrue(settings.showsCompletedTasks)
        XCTAssertTrue(settings.showsProgressPercentage)
        XCTAssertTrue(settings.showsNotes)
    }

    func testTaskDisplayStoragePersistsIndependentlyFromAppearance() {
        let original = PlanoraTaskDisplayStorage.load()
        let appearanceBefore = PlanoraAppearanceStorage.load()
        defer { PlanoraTaskDisplayStorage.save(original) }
        let settings = PlanoraTaskDisplaySettings(
            density: .compact,
            sortOrder: .deadline,
            showsCompletedTasks: false,
            showsProgressPercentage: true,
            showsNotes: false
        )

        PlanoraTaskDisplayStorage.save(settings)

        XCTAssertEqual(PlanoraTaskDisplayStorage.load(), settings)
        XCTAssertEqual(PlanoraAppearanceStorage.load(), appearanceBefore)
    }

    private func inMemoryContainer() throws -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: PlanoraTask.self, configurations: configuration)
    }

    private func makeTask(index: Int) -> PlanoraTask {
        PlanoraTask(
            title: "Task \(index)",
            subject: index.isMultiple(of: 2) ? "Physics HL" : "Math AA HL",
            type: .assignment,
            deadline: Date(timeIntervalSince1970: 1_800_000_000 + Double(index * 3_600)),
            hasDeadline: true,
            tracksProgress: true,
            progressState: .percentage(Double(index % 100) / 100),
            notes: String(repeating: "note ", count: 8),
            createdDate: Date(timeIntervalSince1970: 1_700_000_000 + Double(index)),
            importance: index % 3
        )
    }

    private func makeRecurringTask(date: Date, seriesID: UUID, sequence: Int) -> PlanoraTask {
        let task = PlanoraTask(
            title: "English Weekly Reading",
            subject: "English B SL",
            type: .assignment,
            deadline: date,
            hasDeadline: true,
            tracksProgress: true,
            progressState: .percentage(0.25),
            notes: "Recurring import fixture",
            createdDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        task.recurrenceRule = TaskRecurrenceRule(
            frequency: .weekly,
            weekdays: [2, 5],
            end: .afterCount(8)
        )
        task.recurrenceSeriesID = seriesID
        task.recurrenceSequence = sequence
        task.recurrenceOccurrenceDate = date
        return task
    }
}
