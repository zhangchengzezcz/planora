import SwiftData
import XCTest
@testable import planora

@MainActor
final class ManageBacIntegrationTests: XCTestCase {
    func testDateParserSupportsISOAndManageBacDisplayDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))

        XCTAssertNotNil(ManageBacDateParser.date(from: "2026-09-10T13:30:00+08:00", calendar: calendar))
        XCTAssertNotNil(ManageBacDateParser.date(from: "Sep 10, 2026 1:30 PM", calendar: calendar))
        XCTAssertNil(ManageBacDateParser.date(from: "Not a date", calendar: calendar))
    }

    func testRepeatedSyncUpdatesRemoteFieldsWithoutDuplicatingOrOverwritingLocalWork() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstRecord = record(title: "Physics IA", deadline: "2026-09-10", identifier: "task-42")

        let firstSummary = try ManageBacTaskImporter.importRecords(
            [firstRecord, firstRecord],
            courses: ["Physics HL", "Physics HL"],
            existingTasks: [],
            into: context
        )

        XCTAssertEqual(firstSummary.importedCount, 1)
        XCTAssertEqual(firstSummary.updatedCount, 0)

        let importedTask = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraTask>()).first)
        importedTask.notes = "Keep my local notes"
        importedTask.priority = .high
        importedTask.setCompleted(true)
        try context.save()

        let secondRecord = record(title: "Physics IA Final", deadline: "2026-09-12", identifier: "task-42")
        let secondSummary = try ManageBacTaskImporter.importRecords(
            [secondRecord],
            courses: ["Physics HL"],
            existingTasks: try context.fetch(FetchDescriptor<PlanoraTask>()),
            into: context
        )

        let tasks = try context.fetch(FetchDescriptor<PlanoraTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(secondSummary.importedCount, 0)
        XCTAssertEqual(secondSummary.updatedCount, 1)
        XCTAssertEqual(tasks[0].title, "Physics IA Final")
        XCTAssertEqual(tasks[0].notes, "Keep my local notes")
        XCTAssertEqual(tasks[0].priority, .high)
        XCTAssertTrue(tasks[0].isCompleted)
        XCTAssertEqual(tasks[0].externalIdentifier, "task-42")
    }

    func testBackupRoundTripPreservesManageBacIdentity() throws {
        let task = PlanoraTask(
            title: "TOK Essay",
            subject: "TOK",
            type: .tok,
            deadline: Date(timeIntervalSince1970: 1_800_000_000),
            hasDeadline: true,
            progressState: .percentage(0.25),
            notes: "Local note"
        )
        task.externalSource = .manageBac
        task.externalIdentifier = "deadline-7"
        task.externalURLString = "https://school.managebac.cn/student/tasks/7"
        task.externalUpdatedAt = Date(timeIntervalSince1970: 1_790_000_000)

        let json = try TaskBackupCodec.json(for: [task])
        let restored = try XCTUnwrap(TaskBackupCodec.tasks(from: json).first)

        XCTAssertEqual(restored.externalSource, .manageBac)
        XCTAssertEqual(restored.externalIdentifier, task.externalIdentifier)
        XCTAssertEqual(restored.externalURLString, task.externalURLString)
        XCTAssertEqual(restored.externalUpdatedAt, task.externalUpdatedAt)
    }

    func testProgrammeDetectionTreatsPDPAsIGCSESuggestion() {
        let courses = [
            ManageBacCourseRecord(
                remoteIdentifier: "math",
                name: "PDP Mathematics",
                teacherNames: [],
                detailURL: nil,
                programmeText: "PDP"
            )
        ]

        let result = ManageBacProgrammeDetector.detect(programmeText: "PDP", courses: courses)

        XCTAssertEqual(result.curriculum, .igcse)
        XCTAssertEqual(result.confidence, .medium)
    }

    func testProgrammeDetectionRecognizesNumberedPDPVariants() {
        for value in ["PDP1 Mathematics", "PDP 2 English", "PDP-2 Chemistry"] {
            let result = ManageBacProgrammeDetector.detect(
                programmeText: value,
                courses: [ManageBacCourseRecord(
                    remoteIdentifier: value,
                    name: value,
                    teacherNames: [],
                    detailURL: nil,
                    programmeText: value
                )]
            )
            XCTAssertEqual(result.curriculum, .igcse, value)
            XCTAssertEqual(result.confidence, .medium, value)
        }
    }

    func testGlobalPerspectivesAliasesNormalizeWithoutReview() {
        for value in ["Global Perspectives", "GP PDP2", "GP PDP2 (Grade 10)", "GPTPD"] {
            let record = ManageBacCourseRecord(
                remoteIdentifier: value,
                name: value,
                teacherNames: [],
                detailURL: nil,
                programmeText: "PDP2"
            )
            let normalized = ManageBacCourseNormalizer.normalize(record, curriculum: .igcse)
            XCTAssertEqual(normalized.canonicalSubject, "Global Perspectives", value)
            XCTAssertEqual(normalized.displayName, "Global Perspectives", value)
            XCTAssertFalse(normalized.requiresReview, value)
        }
    }

    func testStoredManageBacCoursesAreRenormalizedWithoutNetworkAccess() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let course = PlanoraCourse(
            displayName: "GP PDP2 (Grade 10)",
            originalName: "GP PDP2 (Grade 10)",
            curriculum: .igcse,
            teacherNames: [
                "Rehman Naseer naseer@example.com",
                "Teachers Rehman Naseer naseer@example.com"
            ],
            externalSource: .manageBac,
            externalIdentifier: "gp-pdp2"
        )
        let task = PlanoraTask(
            title: "Perspective reflection",
            subject: "GP PDP2 (Grade 10)",
            type: .assignment,
            deadline: nil,
            hasDeadline: false,
            progressState: .percentage(0),
            notes: ""
        )
        task.externalSource = .manageBac
        task.courseID = course.id
        context.insert(course)
        context.insert(task)
        try context.save()

        let changed = try ManageBacTaskImporter.refreshStoredCourseMetadata(in: context)

        XCTAssertEqual(changed, 1)
        XCTAssertEqual(course.displayName, "Global Perspectives")
        XCTAssertEqual(course.canonicalSubject, "Global Perspectives")
        XCTAssertFalse(course.needsRemoteReview)
        XCTAssertEqual(course.teacherNames, ["Rehman Naseer naseer@example.com"])
        XCTAssertEqual(task.subject, "Global Perspectives")
    }

    func testTeacherNameAndEmailArePresentedSeparately() {
        let teacher = ParsedTeacher(rawValue: "Rehman Naseer naseer@example.com")
        XCTAssertEqual(teacher.name, "Rehman Naseer")
        XCTAssertEqual(teacher.email, "naseer@example.com")
    }

    func testSnapshotImportsCourseTeachersUnitsAndRemoteCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let snapshot = ManageBacSyncSnapshot(
            schoolHost: "school.managebac.cn",
            programmeText: "IB Diploma Programme",
            courses: [
                ManageBacCourseRecord(
                    remoteIdentifier: "physics",
                    name: "Physics HL",
                    teacherNames: ["Ms Chen"],
                    detailURL: "https://school.managebac.cn/student/classes/physics",
                    programmeText: "IB Diploma Programme"
                )
            ],
            units: [
                ManageBacUnitRecord(
                    remoteIdentifier: "mechanics",
                    courseIdentifier: "physics",
                    title: "Mechanics",
                    detailURL: nil,
                    startDateText: "2026-08-01",
                    endDateText: "2026-09-01",
                    officialProgress: 0.5
                )
            ],
            tasks: [
                ManageBacTaskRecord(
                    remoteIdentifier: "task-1",
                    title: "Mechanics Quiz",
                    subject: "Physics HL",
                    deadlineText: "2026-09-01",
                    detailURL: nil,
                    sourceView: "completed",
                    courseIdentifier: "physics",
                    unitIdentifier: "mechanics"
                )
            ]
        )

        let summary = try ManageBacTaskImporter.importSnapshot(
            snapshot,
            currentCurriculum: .ib,
            existingTasks: [],
            into: context
        )

        let course = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraCourse>()).first)
        let unit = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraUnit>()).first)
        let task = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraTask>()).first)
        XCTAssertEqual(course.teacherNames, ["Ms Chen"])
        XCTAssertEqual(unit.courseID, course.id)
        XCTAssertEqual(task.courseID, course.id)
        XCTAssertEqual(task.unitID, unit.id)
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(summary.completedCount, 1)
    }

    func testMissingRemoteTaskIsRetainedForReview() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let task = PlanoraTask(
            title: "Existing",
            subject: "Physics",
            type: .assignment,
            deadline: nil,
            hasDeadline: false,
            progressState: .percentage(0),
            notes: ""
        )
        task.externalSource = .manageBac
        task.externalIdentifier = "remote-existing"
        context.insert(task)
        try context.save()

        let summary = try ManageBacTaskImporter.importSnapshot(
            ManageBacSyncSnapshot(
                schoolHost: "school.managebac.cn",
                programmeText: nil,
                courses: [],
                units: [],
                tasks: []
            ),
            currentCurriculum: .ib,
            existingTasks: [task],
            into: context
        )

        XCTAssertFalse(task.isArchived)
        XCTAssertTrue(task.needsRemoteReview)
        XCTAssertEqual(summary.reviewCount, 1)
    }

    func testV9BackupPreservesTeachersAndUnitRelationships() throws {
        let course = PlanoraCourse(
            displayName: "Physics HL",
            curriculum: .ib,
            teacherNames: ["Ms Chen"],
            externalSource: .manageBac,
            externalIdentifier: "physics"
        )
        let unit = PlanoraUnit(
            courseID: course.id,
            title: "Mechanics",
            externalSource: .manageBac,
            externalIdentifier: "mechanics"
        )
        let task = PlanoraTask(
            title: "Quiz",
            subject: course.displayName,
            type: .assignment,
            deadline: nil,
            hasDeadline: false,
            progressState: .percentage(0),
            notes: ""
        )
        task.courseID = course.id
        task.unitID = unit.id

        let json = try TaskBackupCodec.json(for: [task], courses: [course], units: [unit])
        let content = try TaskBackupCodec.content(from: json)

        XCTAssertEqual(content.courses.first?.teacherNames, ["Ms Chen"])
        let restoredCourse = try XCTUnwrap(content.courses.first)
        let restoredUnit = try XCTUnwrap(content.units.first)
        let restoredTask = try XCTUnwrap(content.tasks.first)
        XCTAssertEqual(restoredUnit.courseID, restoredCourse.id)
        XCTAssertEqual(restoredTask.unitID, restoredUnit.id)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: PlanoraTask.self, PlanoraCourse.self, PlanoraUnit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func record(title: String, deadline: String, identifier: String) -> ManageBacTaskRecord {
        ManageBacTaskRecord(
            remoteIdentifier: identifier,
            title: title,
            subject: "Physics HL",
            deadlineText: deadline,
            detailURL: "https://school.managebac.cn/student/tasks/42",
            sourceView: "upcoming"
        )
    }
}
