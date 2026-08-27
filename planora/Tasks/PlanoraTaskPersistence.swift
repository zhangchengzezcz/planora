import SwiftData

@MainActor
enum PlanoraTaskPersistence {
    static func save(_ modelContext: ModelContext) {
        try? modelContext.save()
    }

    static func saveAndSynchronize(_ task: PlanoraTask, in modelContext: ModelContext) {
        save(modelContext)
        let snapshot = TaskReminderTaskSnapshot(task: task)
        Task { await TaskReminderScheduler.synchronize(snapshot: snapshot) }
    }

    static func saveAndReconcile(
        fallbackTasks: [PlanoraTask],
        in modelContext: ModelContext
    ) {
        save(modelContext)
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
