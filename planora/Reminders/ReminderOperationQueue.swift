import Foundation

@MainActor
final class ReminderOperationQueue {
    private var tail: Task<Void, Never>?
    private var latestID: UUID?

    // Notification-center awaits are reentrant; finish each mutation before the next begins.
    func run(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = tail
        let id = UUID()
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        latestID = id
        tail = task
        await task.value
        if latestID == id {
            tail = nil
            latestID = nil
        }
    }
}
