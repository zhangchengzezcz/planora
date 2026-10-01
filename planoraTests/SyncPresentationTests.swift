import XCTest
@testable import planora

final class SyncPresentationTests: XCTestCase {
    func testQuickProgressDoesNotCountUnscannedSteps() {
        XCTAssertEqual(ManageBacSyncPresentation.stepIndices(mode: .quick), [0, 1, 4, 5, 6, 7, 8])
        XCTAssertEqual(ManageBacSyncPresentation.progress(mode: .quick, completed: 4), 2)
        XCTAssertEqual(ManageBacSyncPresentation.progress(mode: .quick, completed: 9), 7)
        XCTAssertEqual(ManageBacSyncPresentation.progress(mode: .full, completed: 9), 9)
    }

    func testMissingAttendanceIsNotShownAsZero() {
        XCTAssertEqual(ManageBacSyncPresentation.attendance(nil), String(localized: "Not Read"))
        let unrecorded = ManageBacAttendanceOverview(present: 0, late: 0, absent: 0, unrecorded: 4)
        XCTAssertEqual(ManageBacSyncPresentation.attendance(unrecorded), String(localized: "Attendance Not Recorded"))
        XCTAssertNotEqual(ManageBacSyncPresentation.attendance(nil), "0")
    }
}
