#if os(macOS)
import AppKit
import SwiftData
import XCTest
@testable import planora

@MainActor
final class MacMenuBarTests: XCTestCase {
    func testWindowPresentationWaitsForActivationAndReusesExistingWindow() {
        let center = NotificationCenter()
        var isActive = false
        var events: [String] = []
        let presenter = MacMainWindowPresenter(notificationCenter: center,
            prepareApplication: { events.append("prepare") },
            isApplicationActive: { isActive },
            activateApplication: { events.append("activate") },
            showExistingWindow: { events.append("restore"); return true })
        presenter.request { events.append("open") }
        XCTAssertEqual(events, ["prepare", "activate"])
        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(events, ["prepare", "activate"])
        isActive = true
        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(events, ["prepare", "activate", "restore"])
        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(events, ["prepare", "activate", "restore"])
    }

    func testRepeatedRequestsOpenOnlyLatestWindowAfterActivation() {
        let center = NotificationCenter()
        var isActive = false
        var activationCount = 0
        var opened: [Int] = []
        let presenter = MacMainWindowPresenter(notificationCenter: center,
            prepareApplication: {}, isApplicationActive: { isActive },
            activateApplication: { activationCount += 1 }, showExistingWindow: { false })
        presenter.request { opened.append(1) }
        presenter.request { opened.append(2) }
        XCTAssertEqual(activationCount, 1)
        XCTAssertTrue(opened.isEmpty)
        isActive = true
        center.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        XCTAssertEqual(opened, [2])
    }

    func testActiveApplicationPresentsWindowWithoutAnotherActivation() {
        var opened = false
        let presenter = MacMainWindowPresenter(prepareApplication: {},
            isApplicationActive: { true },
            activateApplication: { XCTFail("Do not reactivate an active app") },
            showExistingWindow: { false })
        presenter.request { opened = true }
        XCTAssertTrue(opened)
    }

    func testPopoverDismissalDoesNotHideMainWindow() {
        let frame = NSRect(x: 0, y: 0, width: 200, height: 120)
        let popover = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
        let main = NSWindow(contentRect: frame, styleMask: [.titled], backing: .buffered, defer: false)
        popover.isReleasedWhenClosed = false
        main.isReleasedWhenClosed = false
        defer { popover.close(); main.close() }
        popover.orderFront(nil)
        main.orderFront(nil)
        let presentation = MacMenuBarPresentation()
        presentation.window = popover
        presentation.dismiss()
        XCTAssertFalse(popover.isVisible)
        XCTAssertTrue(main.isVisible)
    }

    func testToolbarTaskQueryUsesPersistedDeletionField() throws {
        let container = try ModelContainer(for: Schema(PlanoraPersistence.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let active = PlanoraTask(title: "Active", subject: "Physics", type: .assignment,
            deadline: nil, hasDeadline: false, progressState: .percentage(0), notes: "", isCompleted: false)
        let deleted = PlanoraTask(title: "Deleted", subject: "Physics", type: .assignment,
            deadline: nil, hasDeadline: false, progressState: .percentage(0), notes: "", isCompleted: false)
        deleted.deletedDate = Date()
        context.insert(active)
        context.insert(deleted)
        try context.save()
        let descriptor = FetchDescriptor<PlanoraTask>(predicate: MacTaskToolbarQuery.editableTasks)
        XCTAssertEqual(try context.fetch(descriptor).map(\.id), [active.id])
        active.deletedDate = Date()
        try context.save()
        XCTAssertTrue(try context.fetch(descriptor).isEmpty)
        deleted.deletedDate = nil
        try context.save()
        XCTAssertEqual(try context.fetch(descriptor).map(\.id), [deleted.id])
    }

    override func tearDown() {
        _ = MacTaskRoute.takePendingTask()
        super.tearDown()
    }

    func testTaskRoutePreservesIdentityAndIsConsumedOnce() {
        let id = UUID()
        MacTaskRoute.request(id, notificationCenter: NotificationCenter())
        XCTAssertEqual(MacTaskRoute.takePendingTask(), id)
        XCTAssertNil(MacTaskRoute.takePendingTask())
    }

    func testLatestTaskRequestReplacesAnUnconsumedRequest() {
        MacTaskRoute.request(UUID(), notificationCenter: NotificationCenter())
        let id = UUID()
        MacTaskRoute.request(id, notificationCenter: NotificationCenter())
        XCTAssertEqual(MacTaskRoute.takePendingTask(), id)
    }

    func testMenuBarIconFillsItsTemplateCanvas() throws {
        let image = PlanoraMenuBarIcon.image
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(image.size, NSSize(width: 22, height: 18))
        let data = try XCTUnwrap(image.tiffRepresentation)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: data))
        var minX = bitmap.pixelsWide
        var maxX = -1
        var minY = bitmap.pixelsHigh
        var maxY = -1
        for y in 0..<bitmap.pixelsHigh {
            for x in 0..<bitmap.pixelsWide {
                if (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.2 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
        }
        XCTAssertGreaterThan(CGFloat(maxX - minX + 1) / CGFloat(bitmap.pixelsWide), 0.75)
        XCTAssertGreaterThan(CGFloat(maxY - minY + 1) / CGFloat(bitmap.pixelsHigh), 0.8)
    }
}
#endif
