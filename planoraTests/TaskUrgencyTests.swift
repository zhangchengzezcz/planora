import XCTest
@testable import planora

@MainActor
final class TaskUrgencyTests: XCTestCase {
    func testDeadlineUrgencyDoesNotOverwriteManualPriority() {
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let task = PlanoraTask(title: "Quiz", subject: "Mathematics", type: .assignment,
            deadline: now, hasDeadline: true, progressState: .percentage(0), notes: "")
        task.priority = .low
        XCTAssertTrue(task.automaticHighPriority(at: now))
        task.deadline = now.addingTimeInterval(86_400)
        XCTAssertTrue(task.automaticHighPriority(at: now))
        task.deadline = now.addingTimeInterval(86_401)
        XCTAssertFalse(task.automaticHighPriority(at: now))
        task.deadline = now.addingTimeInterval(-86_400)
        XCTAssertTrue(task.automaticHighPriority(at: now))
        XCTAssertEqual(task.priority, .low)
        task.isCompleted = true
        XCTAssertFalse(task.automaticHighPriority(at: now))
        task.isCompleted = false
        task.archivedDate = now
        XCTAssertFalse(task.automaticHighPriority(at: now))
        task.archivedDate = nil
        task.deletedDate = now
        XCTAssertFalse(task.automaticHighPriority(at: now))
        task.deletedDate = nil
        task.hasDeadline = false
        XCTAssertFalse(task.automaticHighPriority(at: now))
    }
}
