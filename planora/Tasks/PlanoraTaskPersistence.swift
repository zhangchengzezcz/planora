import SwiftData

@MainActor
enum PlanoraTaskPersistence {
    static func save(_ modelContext: ModelContext) {
        try? modelContext.save()
    }

    static func saveAndSynchronize(_ task: PlanoraTask, in modelContext: ModelContext) {
        save(modelContext)
        Task { await TaskReminderScheduler.synchronize(task: task) }
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
        Task { await TaskReminderScheduler.reconcile(tasks: tasks) }
    }
}
