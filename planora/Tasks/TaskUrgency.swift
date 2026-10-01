import Foundation

extension PlanoraTask {
    func automaticHighPriority(at now: Date) -> Bool {
        guard hasDeadline, let deadline, !isCompleted, !isDeleted, !isArchived else { return false }
        return deadline <= now.addingTimeInterval(24 * 60 * 60)
    }

    var displayPriority: TaskPriority {
        automaticHighPriority(at: Date()) ? .high : priority
    }

    var priorityDisplayTitle: String {
        if priority != .high && automaticHighPriority(at: Date()) {
            return String(localized: "High (Automatic)")
        }
        return priority.title
    }
}
