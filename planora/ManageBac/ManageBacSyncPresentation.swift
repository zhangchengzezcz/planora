import Foundation

enum ManageBacSyncPresentation {
    static func stepIndices(mode: ManageBacSyncMode) -> [Int] {
        mode == .quick ? [0, 1, 4, 5, 6, 7, 8] : Array(0..<9)
    }

    static func progress(mode: ManageBacSyncMode, completed: Int) -> Int {
        stepIndices(mode: mode).filter { $0 < completed }.count
    }

    static func attendance(_ overview: ManageBacAttendanceOverview?) -> String {
        guard let overview else { return String(localized: "Not Read") }
        guard let rate = overview.rate else { return String(localized: "Attendance Not Recorded") }
        return "\(overview.recorded) · \(rate.formatted(.percent.precision(.fractionLength(0))))"
    }
}
