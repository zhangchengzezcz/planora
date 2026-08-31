import Foundation
import SwiftData

enum ImportedCurriculumContentAction: String, CaseIterable, Identifiable {
    case keep
    case archive
    case delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keep: String(localized: "Keep Imported Content")
        case .archive: String(localized: "Archive Imported Content")
        case .delete: String(localized: "Delete Imported Content")
        }
    }
}

struct CurriculumSwitchOptions {
    var importedContentAction: ImportedCurriculumContentAction = .archive
    var deletePersonalTasks = false
    var deletePersonalEvents = false
}

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

    static func targets(
        for selectedTasks: [PlanoraTask],
        scope: RecurrenceEditScope,
        in allTasks: [PlanoraTask]
    ) -> [PlanoraTask] {
        var seen = Set<UUID>()
        return selectedTasks
            .flatMap { deletionTargets(for: $0, scope: scope, in: allTasks) }
            .filter { seen.insert($0.id).inserted }
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

        if let json = try? TaskBackupCodec.json(for: targets) {
            store.stageDeletedTasks(json: json, count: targets.count)
        }
        AutomaticTaskBackup.save(tasks: allTasks)
        let deletedAt = Date()
        targets.forEach { $0.deletedDate = deletedAt }
        PlanoraTaskPersistence.save(modelContext)
        Task { await TaskReminderScheduler.removeRequests(forTaskIDs: taskIDs) }
    }

    static func delete(
        _ selectedTasks: [PlanoraTask],
        scope: RecurrenceEditScope,
        allTasks: [PlanoraTask],
        modelContext: ModelContext,
        store: PlanoraStore
    ) {
        let targets = targets(for: selectedTasks, scope: scope, in: allTasks)
        guard !targets.isEmpty else { return }

        AutomaticTaskBackup.save(tasks: allTasks)
        if let json = try? TaskBackupCodec.json(for: targets) {
            store.stageDeletedTasks(json: json, count: targets.count)
        }

        let taskIDs = targets.map(\.id)
        let deletedAt = Date()
        targets.forEach { $0.deletedDate = deletedAt }
        PlanoraTaskPersistence.save(modelContext)
        Task { await TaskReminderScheduler.removeRequests(forTaskIDs: taskIDs) }
    }

    static func restoreFromRecentlyDeleted(
        _ tasks: [PlanoraTask],
        modelContext: ModelContext
    ) {
        tasks.forEach { $0.deletedDate = nil }
        PlanoraTaskPersistence.save(modelContext)
        PlanoraTaskPersistence.reconcile(fallbackTasks: tasks, in: modelContext)
    }

    static func permanentlyDelete(
        _ tasks: [PlanoraTask],
        allTasks: [PlanoraTask],
        modelContext: ModelContext
    ) {
        let taskIDs = tasks.map(\.id)
        for task in tasks {
            if let seriesID = task.recurrenceSeriesID {
                let series = allTasks.filter { $0.recurrenceSeriesID == seriesID }
                RecurringTaskEngine.excludeOccurrence(task, from: series)
            }
            modelContext.delete(task)
        }
        PlanoraTaskPersistence.save(modelContext)
        Task { await TaskReminderScheduler.removeRequests(forTaskIDs: taskIDs) }
    }

    static func switchCurriculum(
        to curriculum: Curriculum,
        tasks: [PlanoraTask],
        courses: [PlanoraCourse],
        units: [PlanoraUnit],
        options: CurriculumSwitchOptions,
        modelContext: ModelContext,
        store: PlanoraStore
    ) {
        AutomaticTaskBackup.save(tasks: tasks, courses: courses, units: units)
        var deletedTaskIDs: [UUID] = []

        for task in tasks {
            if task.externalSource == .manageBac {
                switch options.importedContentAction {
                case .keep:
                    break
                case .archive:
                    task.archivedDate = Date()
                case .delete:
                    deletedTaskIDs.append(task.id)
                    modelContext.delete(task)
                }
                continue
            }

            let shouldDelete = task.type == .event
                ? options.deletePersonalEvents
                : options.deletePersonalTasks
            if shouldDelete {
                deletedTaskIDs.append(task.id)
                modelContext.delete(task)
            }
        }

        for course in courses where course.externalSource == .manageBac {
            switch options.importedContentAction {
            case .keep:
                break
            case .archive:
                course.isArchived = true
            case .delete:
                modelContext.delete(course)
            }
        }

        for unit in units where unit.externalSource == .manageBac {
            switch options.importedContentAction {
            case .keep:
                break
            case .archive:
                unit.isArchived = true
            case .delete:
                modelContext.delete(unit)
            }
        }

        PlanoraTaskPersistence.save(modelContext)
        if !deletedTaskIDs.isEmpty {
            Task { await TaskReminderScheduler.removeRequests(forTaskIDs: deletedTaskIDs) }
        }
        store.selectCurriculum(curriculum)
    }
}
