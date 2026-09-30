import SwiftData
import XCTest
@testable import planora

@MainActor
final class ImportRecoveryTests: XCTestCase {
    private func container() throws -> ModelContainer {
        try ModelContainer(for: Schema(PlanoraPersistence.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func task(_ title: String) -> PlanoraTask {
        PlanoraTask(title: title, subject: "Mathematics", type: .assignment,
            deadline: nil, hasDeadline: false, progressState: .percentage(0), notes: "")
    }

    func testRestoreReplacesLearningRecordsAndRelationships() throws {
        let container = try container()
        let context = container.mainContext
        let original = task("Original")
        let course = PlanoraCourse(displayName: "My course", curriculum: .igcse)
        original.courseID = course.id
        original.subtasks = [PlanoraSubtask(title: "Child", task: original)]
        context.insert(original)
        context.insert(course)
        context.insert(PlanoraTeacher(name: "My teacher", courseIDs: [course.id]))
        context.insert(PlanoraMessage(externalIdentifier: "message", title: "My message", isUnread: true))
        context.insert(PlanoraScheduleEvent(externalIdentifier: "lesson", title: "My lesson",
            startDate: Date(), endDate: Date().addingTimeInterval(3600), attendanceStatus: "present"))
        try context.save()
        let originalID = original.id
        let data = try ImportRecovery.capture(context)
        original.title = "Changed"
        context.insert(task("Unwanted task"))
        context.insert(PlanoraCourse(displayName: "Unwanted course", curriculum: .ib))
        try context.save()
        _ = try ImportRecovery.restore(context, data: data)
        let tasks = try context.fetch(FetchDescriptor<PlanoraTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(tasks.first?.id, originalID)
        XCTAssertEqual(tasks.first?.title, "Original")
        XCTAssertEqual(tasks.first?.subtasks.first?.title, "Child")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraSubtask>()), 1)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraCourse>()), 1)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlanoraTeacher>()).first?.name, "My teacher")
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlanoraMessage>()).first?.isUnread, true)
        XCTAssertEqual(try context.fetch(FetchDescriptor<PlanoraScheduleEvent>()).first?.attendanceStatus, "present")
    }

    func testEmptyPreImportSnapshotCanBeRestored() throws {
        let container = try container()
        let context = container.mainContext
        let data = try ImportRecovery.capture(context)
        context.insert(task("Imported"))
        try context.save()
        _ = try ImportRecovery.restore(context, data: data)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 0)
    }

    func testCorruptSnapshotDoesNotDeleteData() throws {
        let container = try container()
        let context = container.mainContext
        context.insert(task("Keep"))
        try context.save()
        XCTAssertThrowsError(try ImportRecovery.restore(context, data: Data("invalid".utf8)))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 1)
    }

    func testClearRemovesTeachersMessagesAndLessonsAsWellAsTasks() throws {
        let container = try container()
        let context = container.mainContext
        context.insert(task("Imported"))
        context.insert(PlanoraTeacher(name: "Teacher"))
        context.insert(PlanoraMessage(externalIdentifier: "message", title: "Message"))
        context.insert(PlanoraScheduleEvent(externalIdentifier: "lesson", title: "Lesson",
            startDate: Date(), endDate: Date()))
        try context.save()
        try ImportRecovery.clear(context)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTeacher>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraMessage>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraScheduleEvent>()), 0)
    }

    func testFailedImportPreservesPreviousUndoFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models),
            configurations: ModelConfiguration(url: root.appendingPathComponent("Test.store")))
        let destination = root.appendingPathComponent("LatestImport.json")
        let previous = Data("previous undo".utf8)
        try previous.write(to: destination)
        let ticket = try ImportRecovery.begin(container.mainContext)
        XCTAssertNotEqual(try Data(contentsOf: destination), previous)
        ImportRecovery.failed(ticket)
        XCTAssertEqual(try Data(contentsOf: destination), previous)
    }

    func testDiskRestoreSurvivesReopeningStore() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let configuration = ModelConfiguration(url: root.appendingPathComponent("Test.store"))
        let schema = Schema(PlanoraPersistence.models)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = container.mainContext
        let original = task("Original on disk")
        original.subtasks = [PlanoraSubtask(title: "Child on disk", task: original)]
        context.insert(original)
        try context.save()
        let id = original.id
        let checkpoint = try ImportRecovery.capture(context)
        original.title = "Changed"
        context.insert(task("Unwanted"))
        try context.save()
        _ = try ImportRecovery.restore(context, data: checkpoint)
        let reopened = try ModelContainer(for: schema, configurations: configuration)
        let restored = try reopened.mainContext.fetch(FetchDescriptor<PlanoraTask>())
        XCTAssertEqual(restored.count, 1)
        XCTAssertEqual(restored.first?.id, id)
        XCTAssertEqual(restored.first?.title, "Original on disk")
        XCTAssertEqual(restored.first?.subtasks.first?.title, "Child on disk")
    }
}
