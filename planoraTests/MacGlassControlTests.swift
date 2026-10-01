#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import planora

@MainActor
final class MacGlassControlTests: XCTestCase {
    func testContinuousPickerHasStableSizeInBothAppearances() async throws {
        for scheme in [ColorScheme.light, .dark] {
            for mode in GradeDisplayMode.allCases {
                let host = NSHostingView(rootView: GradeModePicker(selection: .constant(mode), modes: GradeDisplayMode.allCases)
                    .padding(20).background(Color(nsColor: .windowBackgroundColor)).preferredColorScheme(scheme))
                let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 196, height: 78),
                    styleMask: [.titled], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = host
                window.orderFront(nil)
                defer { window.close() }
                try await Task.sleep(for: .milliseconds(150))
                host.layoutSubtreeIfNeeded()
                let control = try XCTUnwrap(segmentedControl(in: host))
                XCTAssertEqual(control.controlSize, .large)
                XCTAssertEqual(control.borderShape, .capsule)
                XCTAssertFalse(control.prefersCompactControlSizeMetrics)
                XCTAssertEqual(control.trackingMode, .selectOne)
                XCTAssertEqual(control.selectedSegment, GradeDisplayMode.allCases.firstIndex(of: mode))
                if #available(macOS 27, *) {
                    XCTAssertEqual(control.role, .valueSelection)
                }
                XCTAssertEqual(host.fittingSize.width, 196, accuracy: 1)
                XCTAssertEqual(host.fittingSize.height, 78, accuracy: 1)
                let bitmap = try XCTUnwrap(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let data = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
                try data.write(to: URL(fileURLWithPath: "/private/tmp/planora-182-picker-\(scheme)-\(mode.rawValue).png"))
            }
        }
    }

    private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        return view.subviews.lazy.compactMap { self.segmentedControl(in: $0) }.first
    }
}
#endif
