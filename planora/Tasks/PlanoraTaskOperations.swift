import SwiftData

@MainActor
enum PlanoraTaskOperations {
    static func deletionTargets(
        for task: PlanoraTask,
        scope: RecurrenceEditScope,
        in tasks: [PlanoraTask]
    ) -> [PlanoraTask] {
        guard let seriesID = task.recurrenceSeriesID else { return [task] }

        let series = tasks.filter { $0.recurrenceSeriesID == seriesID }
        switch scope {
        case .occurrence:
            return [task]
        case .future:
            return series.filter { $0.recurrenceSequence >= task.recurrenceSequence }
        case .entireSeries:
            return series
        }
    }

    static func delete(
        _ task: PlanoraTask,
        scope: RecurrenceEditScope,
        allTasks: [PlanoraTask],
        modelContext: ModelContext,
        store: PlanoraStore
    ) {
        let targets = deletionTargets(for: task, scope: scope, in: allTasks)
        let taskIDs = targets.map(\.id)

        if scope == .occurrence,
           let seriesID = task.recurrenceSeriesID {
            RecurringTaskEngine.excludeOccurrence(
                task,
                from: allTasks.filter { $0.recurrenceSeriesID == seriesID }
            )
        }

        if let json = try? TaskBackupCodec.json(for: targets) {
            store.stageDeletedTasks(json: json, count: targets.count)
        }
        AutomaticTaskBackup.save(tasks: allTasks)

        if scope == .future,
           let seriesID = task.recurrenceSeriesID {
            RecurringTaskEngine.truncateSeries(
                before: task,
                in: allTasks.filter { $0.recurrenceSeriesID == seriesID }
            )
        }

        for target in targets {
            modelContext.delete(target)
        }
        PlanoraTaskPersistence.save(modelContext)
        Task { await TaskReminderScheduler.removeRequests(forTaskIDs: taskIDs) }
    }

    static func switchCurriculum(
        to curriculum: Curriculum,
        tasks: [PlanoraTask],
        modelContext: ModelContext,
        store: PlanoraStore
    ) {
        let taskIDs = tasks.map(\.id)
        AutomaticTaskBackup.save(tasks: tasks)

        for task in tasks {
            modelContext.delete(task)
        }

        PlanoraTaskPersistence.save(modelContext)
        Task { await TaskReminderScheduler.removeRequests(forTaskIDs: taskIDs) }
        store.selectCurriculum(curriculum)
    }
}
