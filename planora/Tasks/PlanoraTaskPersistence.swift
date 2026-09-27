import Foundation
import SwiftData

@MainActor
enum PlanoraTaskPersistence {
    static let saveFailed = Notification.Name("PlanoraTaskPersistence.saveFailed")

    @discardableResult
    static func save(_ modelContext: ModelContext) -> Bool {
        commit(save: { try modelContext.save() }, rollback: { modelContext.rollback() })
    }

    // Side effects must only run after the database transaction has succeeded.
    static func commit(save: () throws -> Void, rollback: () -> Void) -> Bool {
        do {
            try save()
            return true
        } catch {
            rollback()
            NotificationCenter.default.post(name: saveFailed, object: nil,
                                            userInfo: ["message": error.localizedDescription])
            return false
        }
    }

    static func saveAndSynchronize(_ task: PlanoraTask, in modelContext: ModelContext) {
        guard save(modelContext) else { return }
        let snapshot = TaskReminderTaskSnapshot(task: task)
        Task { await TaskReminderScheduler.synchronize(snapshot: snapshot) }
    }

    static func saveAndReconcile(
        fallbackTasks: [PlanoraTask],
        in modelContext: ModelContext
    ) {
        guard save(modelContext) else { return }
        reconcile(fallbackTasks: fallbackTasks, in: modelContext)
    }

    static func reconcile(
        fallbackTasks: [PlanoraTask],
        in modelContext: ModelContext
    ) {
        let refreshedTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? fallbackTasks
        reconcile(tasks: refreshedTasks)
    }

    static func reconcile(tasks: [PlanoraTask]) {
        let snapshots = tasks.map(TaskReminderTaskSnapshot.init)
        Task { await TaskReminderScheduler.reconcile(snapshots: snapshots) }
    }
}
