import SwiftData
import XCTest
@testable import planora

@MainActor
final class BackupPerformanceTests: XCTestCase {
    func testLegacyV1BackupUsesSafeDefaults() throws {
        let json = """
        {
          "version": 1,
          "exportedAt": "2024-01-01T00:00:00Z",
          "tasks": [
            {
              "title": "Legacy homework",
              "subject": "Mathematics",
              "deadline": "2024-02-01T00:00:00Z"
            }
          ]
        }
        """

        let tasks = try TaskBackupCodec.tasks(from: json)
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks[0].title, "Legacy homework")
        XCTAssertTrue(tasks[0].hasDeadline)
        XCTAssertEqual(tasks[0].priority, .medium)
        XCTAssertTrue(tasks[0].reminders.isEmpty)
        XCTAssertNil(tasks[0].recurrenceRule)
    }

    func testV3BackupWithoutNewFieldsImports() throws {
        let json = """
        {
          "version": 3,
          "exportedAt": "2025-01-01T00:00:00Z",
          "tasks": [
            {
              "title": "Physics IA",
              "subject": "Physics HL",
              "typeRawValue": "ia",
              "deadline": "2025-09-10T00:00:00Z",
              "hasDeadline": true,
              "tracksProgress": true,
              "progressKindRawValue": "stage",
              "percentageProgress": 0.4,
              "stageName": "Analysis",
              "notes": "Legacy v3",
              "createdDate": "2025-01-01T00:00:00Z",
              "isCompleted": false,
              "importance": 2
            }
          ]
        }
        """

        let task = try XCTUnwrap(TaskBackupCodec.tasks(from: json).first)
        XCTAssertEqual(task.title, "Physics IA")
        XCTAssertEqual(task.priority, .high)
        XCTAssertNil(task.plannedDate)
        XCTAssertFalse(task.isRecurring)
    }

    func testV2BackupWithoutTimelineFieldsImports() throws {
        let json = """
        {
          "version": 2,
          "exportedAt": "2024-08-01T00:00:00Z",
          "tasks": [
            {
              "title": "English reading",
              "subject": "English",
              "typeRawValue": "assignment",
              "hasDeadline": false,
              "progressKindRawValue": "percentage",
              "percentageProgress": 0.25,
              "createdDate": "2024-08-01T00:00:00Z"
            }
          ]
        }
        """

        let task = try XCTUnwrap(TaskBackupCodec.tasks(from: json).first)
        XCTAssertFalse(task.hasDeadline)
        XCTAssertEqual(task.percentageProgress, 0.25)
        XCTAssertNil(task.timelineData)
    }

    func testV7RoundTripPreservesReminderRecurrenceAndPlanningData() throws {
        let task = makeTask(index: 1)
        task.setPlannedDate(Date(timeIntervalSince1970: 1_800_000_000))
        task.reminders = [TaskReminder(timing: .daysBefore(3), hour: 8, minute: 30)]
        task.recurrenceRule = TaskRecurrenceRule(frequency: .weekly, weekdays: [2, 5], end: .afterCount(8))
        task.recurrenceSeriesID = UUID()
        task.recurrenceSequence = 3

        let json = try TaskBackupCodec.json(for: [task])
            .replacingOccurrences(of: "\"version\" : 8", with: "\"version\" : 7")
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

    func testMalformedEmptyAndPartialBackupsDoNotMutateExistingStore() throws {
        let container = try inMemoryContainer()
        let context = container.mainContext
        context.insert(makeTask(index: 0))
        try context.save()

        for invalid in ["{broken", "{\"version\":7,\"tasks\":[]}", "{\"version\":7,\"tasks\":[{\"subject\":\"Physics\"}]}" ] {
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
}
