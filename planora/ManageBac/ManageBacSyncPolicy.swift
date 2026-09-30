import Foundation

enum ManageBacSyncMode: String, Codable, CaseIterable, Identifiable {
    case quick, full
    var id: String { rawValue }
    var title: String { self == .quick ? String(localized: "Quick Sync") : String(localized: "Full Sync") }
    var symbol: String { self == .quick ? "bolt" : "arrow.triangle.2.circlepath" }
}

enum ManageBacSyncPolicy {
    static let quickInterval: TimeInterval = 15 * 60
    static let fullInterval: TimeInterval = 24 * 60 * 60

    static func automaticMode(connection: ManageBacConnectionSnapshot, lastAttempt: Date?, now: Date) -> ManageBacSyncMode? {
        let reference = max(connection.lastSyncDate, lastAttempt ?? .distantPast)
        guard now.timeIntervalSince(reference) >= quickInterval else { return nil }
        guard let lastFull = connection.lastFullSyncDate,
              now.timeIntervalSince(lastFull) < fullInterval else { return .full }
        return .quick
    }

    static func taskPaths(mode: ManageBacSyncMode, courseIDs: [String]) -> [String] {
        let global = ["upcoming", "past", "overdue"].map { "/student/tasks_and_deadlines?view=\($0)" }
        return global + (mode == .full ? courseIDs.map { "/student/classes/\($0)/core_tasks" } : [])
    }
}

enum RecentAttendanceWindow {
    static func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        return DateInterval(start: start, end: now)
    }
}
