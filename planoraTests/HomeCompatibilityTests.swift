#if os(iOS)
import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import planora

@MainActor
final class HomeCompatibilityTests: XCTestCase {
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
                window.frame = scene.coordinateSpace.bounds
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
#endif
