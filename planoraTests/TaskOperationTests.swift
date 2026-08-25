import SwiftData
import XCTest
@testable import planora

@MainActor
final class TaskOperationTests: XCTestCase {
    func testDeletionTargetsForRecurringTaskRespectScope() {
        let seriesID = UUID()
        let tasks = (0..<5).map { index in
            makeTask(title: "Task \(index)", seriesID: seriesID, sequence: index)
        }
        let selected = tasks[2]

        XCTAssertEqual(
            PlanoraTaskOperations.deletionTargets(for: selected, scope: .occurrence, in: tasks).map(\.title),
            ["Task 2"]
        )
        XCTAssertEqual(
            PlanoraTaskOperations.deletionTargets(for: selected, scope: .future, in: tasks).map(\.title),
            ["Task 2", "Task 3", "Task 4"]
        )
        XCTAssertEqual(
            PlanoraTaskOperations.deletionTargets(for: selected, scope: .entireSeries, in: tasks).map(\.title),
            ["Task 0", "Task 1", "Task 2", "Task 3", "Task 4"]
        )
    }

    func testDeletionTargetsForSingleTaskIgnoreSeriesScope() {
        let task = makeTask(title: "Single")

        XCTAssertEqual(
            PlanoraTaskOperations.deletionTargets(for: task, scope: .entireSeries, in: [task]).map(\.title),
            ["Single"]
        )
    }

    func testTaskListProjectionHidesCompletedTasksWithoutChangingSmartOrder() {
        let high = makeTask(title: "High", sequence: 1)
        high.priority = .high
        let low = makeTask(title: "Low", sequence: 0)
        low.priority = .low
        let completed = makeTask(title: "Completed", sequence: 2)
        completed.setCompleted(true)
        var settings = PlanoraTaskDisplaySettings()
        settings.showsCompletedTasks = false
        settings.sortOrder = .smart

        let visibleTasks = PlanoraTaskListProjection.tasks(
            from: [low, completed, high],
            settings: settings
        )

        XCTAssertEqual(visibleTasks.map(\.title), ["High", "Low"])
    }

    func testSearchRankingStillPrefersSubjectAndTypeMatches() {
        let physics = makeTask(title: "Generic worksheet", sequence: 0)
        physics.subject = "Physics HL"
        let essay = makeTask(title: "Physics reflections", sequence: 1)
        essay.subject = "English B SL"
        essay.type = .ee

        let results = PlanoraTaskSearchEngine.results(
            in: [essay, physics],
            query: "physics"
        )

        XCTAssertEqual(results.map(\.title), ["Generic worksheet", "Physics reflections"])
    }

    func testDefaultCurriculumSwitchArchivesManageBacAndKeepsPersonalContent() throws {
        let container = try ModelContainer(
            for: PlanoraTask.self, PlanoraCourse.self, PlanoraUnit.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let personalTask = makeTask(title: "Personal Task")
        let personalEvent = makeTask(title: "Personal Event")
        personalEvent.type = .event
        let importedTask = makeTask(title: "ManageBac Task")
        importedTask.externalSource = .manageBac
        importedTask.externalIdentifier = "task-1"
        let course = PlanoraCourse(
            displayName: "Physics HL",
            curriculum: .ib,
            externalSource: .manageBac,
            externalIdentifier: "physics"
        )
        let unit = PlanoraUnit(
            courseID: course.id,
            title: "Mechanics",
            externalSource: .manageBac,
            externalIdentifier: "mechanics"
        )
        [personalTask, personalEvent, importedTask].forEach(context.insert)
        context.insert(course)
        context.insert(unit)
        try context.save()

        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        PlanoraTaskOperations.switchCurriculum(
            to: .igcse,
            tasks: [personalTask, personalEvent, importedTask],
            courses: [course],
            units: [unit],
            options: CurriculumSwitchOptions(),
            modelContext: context,
            store: store
        )

        XCTAssertEqual(store.curriculum, .igcse)
        XCTAssertFalse(personalTask.isArchived)
        XCTAssertFalse(personalEvent.isArchived)
        XCTAssertTrue(importedTask.isArchived)
        XCTAssertTrue(course.isArchived)
        XCTAssertTrue(unit.isArchived)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<PlanoraTask>()), 3)
    }

    private func makeTask(title: String, seriesID: UUID? = nil, sequence: Int = 0) -> PlanoraTask {
        let task = PlanoraTask(
            title: title,
            subject: "Physics HL",
            type: .assignment,
            deadline: Date(timeIntervalSince1970: 1_800_000_000 + Double(sequence) * 86_400),
            hasDeadline: true,
            tracksProgress: false,
            progressState: .percentage(0),
            notes: ""
        )
        task.recurrenceRule = seriesID == nil ? nil : TaskRecurrenceRule(frequency: .daily, end: .never)
        task.recurrenceSeriesID = seriesID
        task.recurrenceSequence = sequence
        return task
    }
}
