import Foundation

struct PlanoraTaskSortKey: Sendable {
    let isCompleted: Bool
    let importance: Int
    let hasDeadline: Bool
    let deadline: Date?
    let plannedDate: Date?
    let createdDate: Date
    let title: String

    init(task: PlanoraTask) {
        isCompleted = task.isCompleted
        importance = task.importance
        hasDeadline = task.hasDeadline
        deadline = task.deadline
        plannedDate = task.plannedDate
        createdDate = task.createdDate
        title = task.title
    }
}

extension Array where Element == PlanoraTask {
    func planoraSorted(
        using areInIncreasingOrder: (PlanoraTaskSortKey, PlanoraTaskSortKey) -> Bool
    ) -> [PlanoraTask] {
        map { task in
            (task: task, key: PlanoraTaskSortKey(task: task))
        }
        .sorted { lhs, rhs in
            areInIncreasingOrder(lhs.key, rhs.key)
        }
        .map(\.task)
    }
}

nonisolated enum PlanoraTaskOrdering {
    nonisolated static func areInListOrder(
        _ lhs: PlanoraTaskSortKey,
        _ rhs: PlanoraTaskSortKey,
        sortOrder: PlanoraTaskSortOrder
    ) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        switch sortOrder {
        case .smart:
            if let result = comparePriority(lhs, rhs) {
                return result
            }
            if let result = compareDeadline(lhs, rhs) {
                return result
            }
            return lhs.createdDate > rhs.createdDate
        case .deadline:
            if let result = compareDeadline(lhs, rhs) {
                return result
            }
            return lhs.createdDate > rhs.createdDate
        case .priority:
            if let result = comparePriority(lhs, rhs) {
                return result
            }
            return lhs.createdDate > rhs.createdDate
        case .createdDate:
            return lhs.createdDate > rhs.createdDate
        case .title:
            let comparison = lhs.title.localizedStandardCompare(rhs.title)
            if comparison != .orderedSame {
                return comparison == .orderedAscending
            }
            return lhs.createdDate > rhs.createdDate
        }
    }

    nonisolated static func areInDashboardOrder(_ lhs: PlanoraTaskSortKey, _ rhs: PlanoraTaskSortKey) -> Bool {
        if let result = comparePriority(lhs, rhs) {
            return result
        }
        if let result = compareDeadline(lhs, rhs) {
            return result
        }
        return lhs.createdDate < rhs.createdDate
    }

    nonisolated static func areInSearchOrder(_ lhs: PlanoraTaskSortKey, _ rhs: PlanoraTaskSortKey) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        if let result = comparePriority(lhs, rhs) {
            return result
        }
        if let result = compareDeadline(lhs, rhs) {
            return result
        }
        return lhs.createdDate > rhs.createdDate
    }

    nonisolated static func areInPlanningOrder(_ lhs: PlanoraTaskSortKey, _ rhs: PlanoraTaskSortKey) -> Bool {
        if let result = comparePriority(lhs, rhs) {
            return result
        }
        return planningDate(for: lhs) < planningDate(for: rhs)
    }

    nonisolated static func areInSubjectDetailOrder(_ lhs: PlanoraTaskSortKey, _ rhs: PlanoraTaskSortKey) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        if let result = comparePriority(lhs, rhs) {
            return result
        }
        if let result = compareOptionalDates(lhs.deadline, rhs.deadline) {
            return result
        }
        return lhs.createdDate > rhs.createdDate
    }

    nonisolated static func areInCalendarDayOrder(_ lhs: PlanoraTaskSortKey, _ rhs: PlanoraTaskSortKey) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }
        if let result = comparePriority(lhs, rhs) {
            return result
        }
        return lhs.createdDate > rhs.createdDate
    }

    private static func planningDate(for task: PlanoraTaskSortKey) -> Date {
        task.deadline ?? task.plannedDate ?? .distantFuture
    }

    private static func comparePriority(_ lhs: PlanoraTaskSortKey, _ rhs: PlanoraTaskSortKey) -> Bool? {
        guard lhs.importance != rhs.importance else { return nil }
        return lhs.importance > rhs.importance
    }

    private static func compareDeadline(_ lhs: PlanoraTaskSortKey, _ rhs: PlanoraTaskSortKey) -> Bool? {
        switch (lhs.hasDeadline, rhs.hasDeadline) {
        case (true, true):
            return compareDates(lhs.deadline ?? .distantFuture, rhs.deadline ?? .distantFuture)
        case (true, false):
            return true
        case (false, true):
            return false
        case (false, false):
            return nil
        }
    }

    private static func compareOptionalDates(_ lhs: Date?, _ rhs: Date?) -> Bool? {
        switch (lhs, rhs) {
        case let (left?, right?):
            return compareDates(left, right)
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            return nil
        }
    }

    private static func compareDates(_ lhs: Date, _ rhs: Date) -> Bool? {
        guard lhs != rhs else { return nil }
        return lhs < rhs
    }
}
