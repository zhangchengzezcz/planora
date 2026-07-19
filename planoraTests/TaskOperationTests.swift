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
