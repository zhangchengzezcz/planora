#if os(macOS)
import AppKit
import SwiftUI
import XCTest
@testable import planora

@MainActor
final class MacGlassControlTests: XCTestCase {
    func testTextSegmentsFitCompleteLocalizedLabels() {
        let font = NSFont.systemFont(ofSize: NSFont.systemFontSize(for: .large), weight: .semibold)
        for labels in [["In Progress", "Completed", "Archived", "Recently Deleted"],
                       ["进行中", "已完成", "已归档", "最近删除"],
                       ["進行中", "完了", "アーカイブ済み", "最近削除した項目"]] {
            let width = MacModePickerGeometry.segmentWidth(labels: labels, showsLabels: true)
            for label in labels {
                XCTAssertGreaterThanOrEqual(width, ceil((label as NSString).size(withAttributes: [.font: font]).width) + 32)
            }
        }
        XCTAssertEqual(MacModePickerGeometry.segmentWidth(labels: ["Recently Deleted"], showsLabels: false), 52)
    }

    func testDragSelectionIsBoundedAndRejectsInvalidGeometry() {
        XCTAssertEqual(MacModePickerGeometry.index(at: -100, width: 156, count: 3), 0)
        XCTAssertEqual(MacModePickerGeometry.index(at: 52, width: 156, count: 3), 1)
        XCTAssertEqual(MacModePickerGeometry.index(at: 104, width: 156, count: 3), 2)
        XCTAssertEqual(MacModePickerGeometry.index(at: 500, width: 156, count: 3), 2)
        XCTAssertNil(MacModePickerGeometry.index(at: .nan, width: 156, count: 3))
        XCTAssertNil(MacModePickerGeometry.index(at: 50, width: 0, count: 3))
        XCTAssertNil(MacModePickerGeometry.index(at: 50, width: 156, count: 0))
    }

    func testNativeTextSegmentsDoNotPadEveryItemToTheLongestLabel() {
        let labels = ["In Progress", "Completed", "Archived", "Recently Deleted"]
        let width = MacModePickerGeometry.totalWidth(labels: labels, showsLabels: true)
        XCTAssertLessThan(width, CGFloat(labels.count) * MacModePickerGeometry.segmentWidth(labels: labels, showsLabels: true))
        XCTAssertEqual(MacModePickerGeometry.totalWidth(labels: labels, showsLabels: false), 208)
    }

    func testPickerHasStableSizeAndUsesNativeTabsOnMacOS27() throws {
        for scheme in [ColorScheme.light, .dark] {
            for mode in GradeDisplayMode.allCases {
                let host = NSHostingView(rootView: GradeModePicker(selection: .constant(mode), modes: GradeDisplayMode.allCases)
                    .padding(20).preferredColorScheme(scheme))
                XCTAssertEqual(host.fittingSize.width, 196, accuracy: 1)
                XCTAssertEqual(host.fittingSize.height, 78, accuracy: 1)
                host.layoutSubtreeIfNeeded()
                if #available(macOS 27, *) {
                    let control = try XCTUnwrap(segmentedControl(in: host))
                    XCTAssertEqual(control.role, .tabs)
                    XCTAssertEqual(control.controlSize, .large)
                    XCTAssertEqual(control.segmentCount, 3)
                    XCTAssertEqual(control.selectedSegment, GradeDisplayMode.allCases.firstIndex(of: mode))
                    XCTAssertEqual(control.borderShape, .capsule)
                }
            }
        }
    }

    func testNativeSelectionUpdatesBinding() throws {
        guard #available(macOS 27, *) else { return }
        var selected = 0
        let picker = MacNativeModePicker(selection: Binding(get: { selected }, set: { selected = $0 }),
            values: [0, 1, 2], title: "Mode", label: { String($0) },
            symbol: { _ in "circle" }, showsLabels: false)
        let coordinator = picker.makeCoordinator()
        let control = NSSegmentedControl()
        control.segmentCount = 3
        control.selectedSegment = 2
        coordinator.selectionChanged(control)
        XCTAssertEqual(selected, 2)
        control.isEnabled = false
        control.selectedSegment = 1
        coordinator.selectionChanged(control)
        XCTAssertEqual(selected, 2)
    }

    private func segmentedControl(in view: NSView) -> NSSegmentedControl? {
        if let control = view as? NSSegmentedControl { return control }
        return view.subviews.lazy.compactMap { self.segmentedControl(in: $0) }.first
    }
}
#endif
