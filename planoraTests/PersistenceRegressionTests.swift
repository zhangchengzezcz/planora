import SwiftData
import XCTest
@testable import planora

@MainActor
final class PersistenceRegressionTests: XCTestCase {
    func testFreshStoreAndRepeatedImportWithStaleQuery() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try PlanoraPersistence.prepareStore(in: root)
        XCTAssertEqual(url.lastPathComponent, "Planora.store")
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models), configurations: ModelConfiguration(url: url))
        let snapshot = ManageBacSyncSnapshot(schoolHost: "school.managebac.cn", courses: [], units: [], tasks: [
            ManageBacTaskRecord(remoteIdentifier: "fresh-task", title: "First import", subject: "Physics", deadlineText: "2026-09-18", detailURL: nil, sourceView: "completed")
        ])
        _ = try ManageBacTaskImporter.importSnapshot(snapshot, currentCurriculum: .igcse, existingTasks: [], into: container.mainContext)
        _ = try ManageBacTaskImporter.importSnapshot(snapshot, currentCurriculum: .igcse, existingTasks: [], into: container.mainContext)
        let tasks = try container.mainContext.fetch(FetchDescriptor<PlanoraTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertTrue(try XCTUnwrap(tasks.first).isCompleted)
    }

    func testDuplicateCourseAndMessageKeysDoNotCrashOrDeleteRecords() throws {
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        for _ in 0..<3 {
            container.mainContext.insert(PlanoraCourse(displayName: "Physics", curriculum: .igcse, externalSource: .manageBac, externalIdentifier: "course-1"))
            container.mainContext.insert(PlanoraMessage(externalIdentifier: "message-1", title: "Message"))
        }
        try container.mainContext.save()
        let snapshot = ManageBacSyncSnapshot(schoolHost: "school.managebac.cn", courses: [
            ManageBacCourseRecord(remoteIdentifier: "course-1", name: "Physics", teacherNames: [], detailURL: nil, programmeText: "IGCSE")
        ], units: [], tasks: [])
        for _ in 0..<2 {
            _ = try ManageBacTaskImporter.importSnapshot(snapshot, currentCurriculum: .igcse, existingTasks: [], into: container.mainContext)
        }
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<PlanoraCourse>()).count, 3)
        XCTAssertEqual(try container.mainContext.fetch(FetchDescriptor<PlanoraMessage>()).count, 3)
    }

#if os(macOS)
    func testCopiedLegacyStoreMigrationAndImport() throws {
        // The private fixture is never committed or bundled. Only a temporary copy is opened.
        let fixture = URL(fileURLWithPath: "/tmp/planora-173-store-fixture")
        guard FileManager.default.fileExists(atPath: fixture.appendingPathComponent("default.store").path) else {
            throw XCTSkip("Provide a local copy of the legacy store in /tmp/planora-173-store-fixture")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.copyItem(at: fixture, to: root)
        defer { try? FileManager.default.removeItem(at: root) }
        let oldData = try Data(contentsOf: root.appendingPathComponent("default.store"))
        let url = try PlanoraPersistence.prepareStore(in: root)
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models), configurations: ModelConfiguration(url: url))
        let context = container.mainContext
        let tasks = try context.fetch(FetchDescriptor<PlanoraTask>())
        let courses = try context.fetch(FetchDescriptor<PlanoraCourse>())
        XCTAssertEqual(tasks.count, 93)
        XCTAssertEqual(courses.count, 36)
        let snapshot = ManageBacSyncSnapshot(schoolHost: "school.managebac.cn", courses: courses.compactMap { course in
            guard let identifier = course.externalIdentifier else { return nil }
            return ManageBacCourseRecord(remoteIdentifier: identifier, name: course.originalName, teacherNames: course.teacherNames, detailURL: nil, programmeText: "IGCSE")
        }, units: [], tasks: tasks.compactMap { task in
            guard let identifier = task.externalIdentifier else { return nil }
            return ManageBacTaskRecord(remoteIdentifier: identifier, title: task.title, subject: task.subject,
                                      deadlineText: task.deadline?.ISO8601Format(), detailURL: nil, sourceView: "tasks")
        })
        for _ in 0..<2 {
            _ = try ManageBacTaskImporter.importSnapshot(snapshot, currentCurriculum: .igcse, existingTasks: [], into: context)
        }
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlanoraTask>()).count, tasks.count)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlanoraCourse>()).count, courses.count)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("default.store")), oldData)
        XCTAssertEqual(try PlanoraPersistence.prepareStore(in: root), url)
    }
#endif
}
