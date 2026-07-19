import XCTest
@testable import planora

@MainActor
final class TaskOrderingTests: XCTestCase {
    func testListSmartOrderKeepsOpenTasksFirstThenPriorityDeadlineAndNewestFallback() {
        let highLater = makeTask(title: "High Later", priority: .high, deadlineOffset: 3, createdOffset: 1)
        let highSooner = makeTask(title: "High Sooner", priority: .high, deadlineOffset: 1, createdOffset: 2)
        let mediumSooner = makeTask(title: "Medium Sooner", priority: .medium, deadlineOffset: 1, createdOffset: 3)
        let completed = makeTask(title: "Completed", priority: .high, deadlineOffset: 0, createdOffset: 4, completed: true)

        let sorted = [completed, mediumSooner, highLater, highSooner].planoraSorted {
            PlanoraTaskOrdering.areInListOrder($0, $1, sortOrder: .smart)
        }

        XCTAssertEqual(sorted.map(\.title), ["High Sooner", "High Later", "Medium Sooner", "Completed"])
    }

    func testDashboardOrderKeepsOlderCreatedDateFallback() {
        let older = makeTask(title: "Older", priority: .medium, deadlineOffset: nil, createdOffset: 1)
        let newer = makeTask(title: "Newer", priority: .medium, deadlineOffset: nil, createdOffset: 2)

        let sorted = [newer, older].planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInDashboardOrder(lhs, rhs)
        }

        XCTAssertEqual(sorted.map(\.title), ["Older", "Newer"])
    }

    func testSearchOrderKeepsNewestCreatedDateFallback() {
        let older = makeTask(title: "Older", priority: .medium, deadlineOffset: nil, createdOffset: 1)
        let newer = makeTask(title: "Newer", priority: .medium, deadlineOffset: nil, createdOffset: 2)

        let sorted = [older, newer].planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInSearchOrder(lhs, rhs)
        }

        XCTAssertEqual(sorted.map(\.title), ["Newer", "Older"])
    }

    func testPlanningOrderUsesPriorityThenDeadlineOrPlannedDate() {
        let plannedSooner = makeTask(title: "Planned Sooner", priority: .medium, deadlineOffset: nil, createdOffset: 1)
        plannedSooner.setPlannedDate(Date(timeIntervalSince1970: 1_800_086_400))
        let dueLater = makeTask(title: "Due Later", priority: .medium, deadlineOffset: 3, createdOffset: 2)
        let highPriority = makeTask(title: "High Priority", priority: .high, deadlineOffset: 10, createdOffset: 3)

        let sorted = [dueLater, plannedSooner, highPriority].planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInPlanningOrder(lhs, rhs)
        }

        XCTAssertEqual(sorted.map(\.title), ["High Priority", "Planned Sooner", "Due Later"])
    }

    func testSubjectDetailOrderKeepsOpenTasksFirstAndNewestFallback() {
        let completed = makeTask(title: "Completed", priority: .high, deadlineOffset: 1, createdOffset: 3, completed: true)
        let older = makeTask(title: "Older", priority: .medium, deadlineOffset: nil, createdOffset: 1)
        let newer = makeTask(title: "Newer", priority: .medium, deadlineOffset: nil, createdOffset: 2)

        let sorted = [completed, older, newer].planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInSubjectDetailOrder(lhs, rhs)
        }

        XCTAssertEqual(sorted.map(\.title), ["Newer", "Older", "Completed"])
    }

    func testCalendarDayOrderDoesNotUseDeadlineFallbackWithinSameDay() {
        let older = makeTask(title: "Older", priority: .medium, deadlineOffset: 0, createdOffset: 1)
        let newer = makeTask(title: "Newer", priority: .medium, deadlineOffset: 0, createdOffset: 2)

        let sorted = [older, newer].planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInCalendarDayOrder(lhs, rhs)
        }

        XCTAssertEqual(sorted.map(\.title), ["Newer", "Older"])
    }

    private func makeTask(
        title: String,
        priority: TaskPriority,
        deadlineOffset: Int?,
        createdOffset: TimeInterval,
        completed: Bool = false
    ) -> PlanoraTask {
        let baseDate = Date(timeIntervalSince1970: 1_800_000_000)
        let deadline = deadlineOffset.map { baseDate.addingTimeInterval(Double($0) * 86_400) }
        let task = PlanoraTask(
            title: title,
            subject: "Physics HL",
            type: .assignment,
            deadline: deadline,
            hasDeadline: deadline != nil,
            tracksProgress: false,
            progressState: .percentage(0),
            notes: "",
            createdDate: baseDate.addingTimeInterval(createdOffset),
            isCompleted: completed,
            completedDate: completed ? baseDate : nil,
            importance: priority.rawValue
        )
        return task
    }
}
