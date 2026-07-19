import SwiftData
import SwiftUI
import UIKit
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

    func testSearchEngineHandlesTwoThousandTasksWithoutRepeatedWork() {
        let tasks = (0..<2_000).map { index in
            makeTask(
                title: index.isMultiple(of: 100) ? "Needle \(index)" : "Task \(index)",
                priority: .medium,
                deadlineOffset: index % 30,
                createdOffset: TimeInterval(index)
            )
        }

        let start = CFAbsoluteTimeGetCurrent()
        let results = PlanoraTaskSearchEngine.results(in: tasks, query: "needle")
        let duration = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(results.count, 20)
        XCTAssertTrue(results.allSatisfy { $0.title.hasPrefix("Needle") })
        XCTAssertLessThan(duration, 2)
    }

    func testSearchViewRendersOneThousandTasksWithoutBlockingTheMainThread() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: PlanoraTask.self, configurations: configuration)
        for index in 0..<1_000 {
            container.mainContext.insert(
                makeTask(
                    title: "Search Task \(index)",
                    priority: TaskPriority(rawValue: index % 3) ?? .medium,
                    deadlineOffset: index % 30,
                    createdOffset: TimeInterval(index)
                )
            )
        }
        try container.mainContext.save()

        let rootView = NavigationStack {
            EventSearchView(store: .previewDashboard, isActive: false)
        }
        .modelContainer(container)
        let controller = UIHostingController(rootView: rootView)
        let frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
        )
        let window = UIWindow(windowScene: windowScene)
        window.frame = frame
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        let start = CFAbsoluteTimeGetCurrent()
        controller.loadViewIfNeeded()
        controller.view.frame = frame
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        let duration = CFAbsoluteTimeGetCurrent() - start

        XCTAssertNotNil(controller.view.window)
        XCTAssertLessThan(duration, 3)
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
