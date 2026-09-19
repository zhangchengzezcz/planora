#if os(iOS)
import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import planora

@MainActor
final class HomeCompatibilityTests: XCTestCase {
    func testWeeklyCalendarSwitchingAndResizing() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        let state = CalendarTestState()
        let tasks = (0..<28).map { index in
            PlanoraTask(title: "Calendar task \(index)", subject: "Physics", type: .assignment,
                        deadline: Calendar.current.date(byAdding: .day, value: index % 14, to: state.date), hasDeadline: true,
                        progressState: .percentage(0.4), notes: "", isCompleted: index % 3 == 0)
        }
        tasks.forEach { container.mainContext.insert($0) }
        try container.mainContext.save()
        let controller = UIHostingController(rootView: CalendarTransitionHarness(state: state, store: store, tasks: tasks).modelContainer(container))
        let window = UIWindow(windowScene: scene)
        window.frame = scene.effectiveGeometry.coordinateSpace.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        for width in [320.0, 834.0, 1194.0] {
            window.frame.size.width = width
            for iteration in 0..<6 {
                state.week = iteration % 2 == 0
                state.date = Calendar.current.date(byAdding: .weekOfYear, value: iteration % 2 == 0 ? 1 : -1, to: state.date)!
                try await Task.sleep(for: .milliseconds(200))
                controller.view.layoutIfNeeded()
                for scroll in scrollViews(in: controller.view) {
                    XCTAssertTrue(scroll.contentSize.height.isFinite)
                    XCTAssertTrue(scroll.contentSize.width.isFinite)
                    XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1)
                }
            }
            state.week = true
            try await Task.sleep(for: .milliseconds(200))
            capture(controller.view, name: "week-transition-width-\(Int(width))")
        }
    }

    func testHomeEmptyAndPopulatedLayouts() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        store.userName = "Mitty"
        for populated in [false, true] {
            if populated {
                for index in 0..<8 {
                    let task = PlanoraTask(title: "Physics investigation \(index + 1)", subject: "Physics", type: .assignment,
                                           deadline: Date().addingTimeInterval(Double(index + 1) * 86400), hasDeadline: true,
                                           progressState: .percentage(0.4), notes: "", isCompleted: index > 5)
                    container.mainContext.insert(task)
                }
                try container.mainContext.save()
            }
            for scheme in [ColorScheme.light, .dark] {
                let controller = UIHostingController(rootView: NavigationStack {
                    HomeDashboardView(store: store, onCreateRequested: {})
                }.modelContainer(container).preferredColorScheme(scheme))
                let window = UIWindow(windowScene: scene)
                window.frame = scene.effectiveGeometry.coordinateSpace.bounds
                window.rootViewController = controller
                window.makeKeyAndVisible()
                defer { window.isHidden = true; window.rootViewController = nil }
                try await Task.sleep(for: .milliseconds(500))
                controller.view.layoutIfNeeded()
                let suffix = "\(populated ? "tasks" : "empty")-\(scheme)"
                capture(controller.view, name: "home-\(suffix)-top")
                if let scroll = scrollViews(in: controller.view).max(by: { $0.contentSize.height < $1.contentSize.height }) {
                    XCTAssertLessThanOrEqual(scroll.contentSize.width, scroll.bounds.width + 1)
                    scroll.setContentOffset(CGPoint(x: 0, y: max(0, scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)), animated: false)
                    try await Task.sleep(for: .milliseconds(300))
                    capture(controller.view, name: "home-\(suffix)-bottom")
                }
            }
        }
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func capture(_ view: UIView, name: String) {
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor @Observable
private final class CalendarTestState {
    var week = false
    var date = Date()
}

private struct CalendarTransitionHarness: View {
    @Bindable var state: CalendarTestState
    let store: PlanoraStore
    let tasks: [PlanoraTask]

    var body: some View {
        NavigationStack {
            List {
                VStack {
                    Picker("Calendar", selection: $state.week) {
                        Text("Week").tag(true)
                        Text("Month").tag(false)
                    }.pickerStyle(.segmented)
                    if state.week {
                        HomeWeekCalendar(store: store, tasks: tasks, selectedDate: $state.date)
                    } else {
                        CalendarPreview(store: store, tasks: tasks, monthDate: $state.date)
                    }
                }
            }
        }
    }
}
#endif
