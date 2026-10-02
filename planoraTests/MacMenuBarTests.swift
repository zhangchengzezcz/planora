#if os(macOS)
import AppKit
import XCTest
@testable import planora

@MainActor
final class MacMenuBarTests: XCTestCase {
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
