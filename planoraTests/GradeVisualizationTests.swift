import XCTest
@testable import planora

@MainActor
final class GradeVisualizationTests: XCTestCase {
    func testManageBacNumericAndTextGrades() {
        let task = PlanoraTask(title: "Lab", subject: "Physics", type: .assignment,
            deadline: Date(timeIntervalSince1970: 1_800_000_000), hasDeadline: true,
            progressState: .percentage(0), notes: "")
        task.externalSource = .manageBac
        task.remoteGradeText = "7"
        task.remoteScoreEarned = 18
        task.remoteScorePossible = 20
        let grade = GradeEntry(task: task)
        XCTAssertEqual(grade?.fraction, 0.9)
        XCTAssertEqual(grade?.subject, "Physics")
        XCTAssertEqual(grade?.date, task.deadline)

        task.remoteScoreEarned = nil
        task.remoteScorePossible = nil
        XCTAssertNotNil(GradeEntry(task: task))
        XCTAssertNil(GradeEntry(task: task)?.fraction)
    }

    func testUnscoredAndDeletedTasksAreExcluded() {
        let task = PlanoraTask(title: "Pending", subject: "Physics", type: .assignment,
            deadline: nil, hasDeadline: false, progressState: .percentage(0), notes: "")
        task.externalSource = .manageBac
        XCTAssertNil(GradeEntry(task: task))
        task.remoteScoreEarned = 7
        task.remoteScorePossible = 10
        XCTAssertNotNil(GradeEntry(task: task))
        task.deletedDate = Date()
        XCTAssertNil(GradeEntry(task: task))
    }
}
