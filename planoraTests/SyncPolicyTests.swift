import SwiftData
import XCTest
#if os(macOS)
import AppKit
#endif
@testable import planora

@MainActor
final class SyncPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func connection(age: TimeInterval, fullAge: TimeInterval?) -> ManageBacConnectionSnapshot {
        ManageBacConnectionSnapshot(schoolHost: "school.managebac.cn", lastSyncDate: now.addingTimeInterval(-age),
            courseCount: 3, taskCount: 20, lastFullSyncDate: fullAge.map { now.addingTimeInterval(-$0) })
    }

    func testAutomaticSyncIsThrottledAcrossRelaunchAndFailure() {
        XCTAssertNil(ManageBacSyncPolicy.automaticMode(connection: connection(age: 100, fullAge: nil), lastAttempt: nil, now: now))
        XCTAssertNil(ManageBacSyncPolicy.automaticMode(connection: connection(age: 3600, fullAge: nil), lastAttempt: now, now: now))
        XCTAssertEqual(ManageBacSyncPolicy.automaticMode(connection: connection(age: 900, fullAge: 3600), lastAttempt: nil, now: now), .quick)
        XCTAssertEqual(ManageBacSyncPolicy.automaticMode(connection: connection(age: 900, fullAge: 86400), lastAttempt: nil, now: now), .full)
        XCTAssertEqual(ManageBacSyncPolicy.automaticMode(connection: connection(age: 900, fullAge: nil), lastAttempt: nil, now: now), .full)
    }

    func testQuickPlanDoesNotReadEveryCourseTaskPage() {
        let ids = ["1", "2", "3"]
        XCTAssertEqual(ManageBacSyncPolicy.taskPaths(mode: .quick, courseIDs: ids).count, 3)
        XCTAssertEqual(ManageBacSyncPolicy.taskPaths(mode: .full, courseIDs: ids).count, 6)
        XCTAssertFalse(ManageBacSyncPolicy.taskPaths(mode: .quick, courseIDs: ids).contains { $0.contains("core_tasks") })
    }

    func testFullSyncReadsTimetableByDefaultAndSupportsOptionalModules() {
        XCTAssertEqual(ManageBacSyncPolicy.workspacePaths(mode: .full), ["/student/notifications", "/student/timetables"])
        XCTAssertEqual(ManageBacSyncPolicy.workspacePaths(mode: .full, messages: false), ["/student/timetables"])
        XCTAssertTrue(ManageBacSyncPolicy.workspacePaths(mode: .full, messages: false, timetable: false).isEmpty)
        XCTAssertEqual(ManageBacSyncPolicy.workspacePaths(mode: .quick, messages: false, timetable: false).count, 2)
    }

    func testRecentAttendanceExcludesOldAndFutureLessons() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        let interval = RecentAttendanceWindow.interval(now: now, calendar: calendar)
        XCTAssertEqual(interval.start, calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)))
        XCTAssertEqual(interval.end, now)
        XCTAssertFalse(interval.contains(now.addingTimeInterval(-8 * 86400)))
        XCTAssertFalse(interval.contains(now.addingTimeInterval(3600)))
    }

    func testPartialImportPreservesUnscannedCoursesUnitsAndTasks() throws {
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let course = PlanoraCourse(displayName: "My course", curriculum: .igcse,
            externalSource: .manageBac, externalIdentifier: "1")
        let unit = PlanoraUnit(courseID: course.id, title: "My unit", externalSource: .manageBac, externalIdentifier: "unit")
        context.insert(course)
        context.insert(unit)
        let task = PlanoraTask(title: "Old completed task", subject: "Mathematics", type: .assignment,
            deadline: nil, hasDeadline: false, progressState: .percentage(1), notes: "", isCompleted: true)
        context.insert(task)
        let snapshot = ManageBacSyncSnapshot(schoolHost: "school.managebac.cn", courses: [], units: [], tasks: [])
        _ = try ManageBacTaskImporter.importSnapshot(snapshot, currentCurriculum: .igcse, existingTasks: [], into: context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraCourse>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraUnit>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 1)
        XCTAssertTrue(task.isCompleted)
        XCTAssertFalse(course.isArchived)
        XCTAssertFalse(unit.isArchived)
    }

#if os(macOS)
    func testMenuBarUsesSystemTemplateAndKeepsAppResident() {
        XCTAssertTrue(PlanoraMenuBarIcon.image.isTemplate)
        XCTAssertEqual(PlanoraMenuBarIcon.image.size, NSSize(width: 22, height: 18))
        XCTAssertFalse(PlanoraAppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }
#endif
}
