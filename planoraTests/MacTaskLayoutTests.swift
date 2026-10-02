#if os(macOS)
import AppKit
import SwiftData
import SwiftUI
import XCTest
@testable import planora

@MainActor
final class MacTaskLayoutTests: XCTestCase {
    func testMainWindowTaskSelectionRendersToolbarWithoutCrashing() async throws {
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        let tasks = (0..<3).map { index in
            PlanoraTask(title: "Task \(index)", subject: "Physics", type: .assignment,
                deadline: nil, hasDeadline: false, progressState: .percentage(0), notes: "", isCompleted: false)
        }
        tasks.forEach(container.mainContext.insert)
        try container.mainContext.save()
        let controller = NSHostingController(rootView: MacMainView(store: store, initialTaskID: tasks[0].id)
            .modelContainer(container).id(tasks[0].id))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 760),
            styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.close() }
        for task in tasks {
            controller.rootView = MacMainView(store: store, initialTaskID: task.id)
                .modelContainer(container).id(task.id)
            try await Task.sleep(for: .milliseconds(250))
            controller.view.layoutSubtreeIfNeeded()
            XCTAssertEqual(try container.mainContext.fetchCount(FetchDescriptor<PlanoraTask>()), 3)
        }
    }

    func testTaskWorkspaceWithFullPageDetailCanShrink() async throws {
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let task = PlanoraTask(title: "Workspace layout", subject: "Physics", type: .assignment,
                               deadline: Date(), hasDeadline: true, progressState: .percentage(0.4), notes: "", isCompleted: false)
        container.mainContext.insert(task)
        try container.mainContext.save()
        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        let controller = NSHostingController(rootView:
            MacTaskWorkspaceView(store: store, searchText: "", selection: .constant(task.id))
        .modelContainer(container))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 650), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.close() }
        for width in [1100.0, 800.0, 650.0] {
            window.setContentSize(NSSize(width: width, height: 520))
            try await Task.sleep(for: .milliseconds(350))
            controller.view.layoutSubtreeIfNeeded()
            XCTAssertEqual(controller.view.bounds.width, width, accuracy: 1)
            XCTAssertLessThanOrEqual(window.contentMinSize.width, 650)
            XCTAssertTrue(window.sheets.isEmpty, "Task details must navigate in-place, not open a sheet")
            if let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) {
                controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
                let image = NSImage(size: controller.view.bounds.size)
                image.addRepresentation(bitmap)
                let attachment = XCTAttachment(image: image)
                attachment.name = "mac-workspace-\(Int(width))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }

    func testDetailResizesWithoutSavingUnchangedTasks() async throws {
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        let task = PlanoraTask(title: "Investigation with a long task title for narrow windows", subject: "Physics", type: .assignment,
                               deadline: Date(), hasDeadline: true, progressState: .percentage(0.4), notes: "", isCompleted: false)
        container.mainContext.insert(task)
        try container.mainContext.save()
        let controller = NSHostingController(rootView: NavigationStack {
            TaskDetailView(store: store, task: task)
        }.modelContainer(container))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 700, height: 720), styleMask: [.titled, .resizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.orderFront(nil)
        defer { window.close() }
        for width in [1400.0, 700.0, 380.0, 520.0] {
            window.setContentSize(NSSize(width: width, height: 520))
            try await Task.sleep(for: .milliseconds(250))
            controller.view.layoutSubtreeIfNeeded()
            XCTAssertEqual(controller.view.bounds.width, width, accuracy: 1)
            XCTAssertFalse(container.mainContext.hasChanges)
            if let bitmap = controller.view.bitmapImageRepForCachingDisplay(in: controller.view.bounds) {
                controller.view.cacheDisplay(in: controller.view.bounds, to: bitmap)
                let image = NSImage(size: controller.view.bounds.size)
                image.addRepresentation(bitmap)
                let attachment = XCTAttachment(image: image)
                attachment.name = "mac-task-detail-\(Int(width))"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
        }
    }
}
#endif
