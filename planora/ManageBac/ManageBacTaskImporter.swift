import Foundation
import SwiftData

@MainActor
enum ManageBacTaskImporter {
    static func importSnapshot(
        _ snapshot: ManageBacSyncSnapshot,
        currentCurriculum: Curriculum,
        existingTasks: [PlanoraTask],
        into modelContext: ModelContext
    ) throws -> ManageBacImportSummary {
        let detection = ManageBacProgrammeDetector.detect(programmeText: snapshot.programmeText, courses: snapshot.courses)
        let curriculum = detection.curriculum ?? currentCurriculum
        let existingCourses = (try? modelContext.fetch(FetchDescriptor<PlanoraCourse>())) ?? []
        let existingUnits = (try? modelContext.fetch(FetchDescriptor<PlanoraUnit>())) ?? []
        var coursesByRemoteID = Dictionary(uniqueKeysWithValues: existingCourses.compactMap { course -> (String, PlanoraCourse)? in
            guard course.externalSource == .manageBac, let identifier = course.externalIdentifier else { return nil }
            return (identifier, course)
        })
        var unitsByRemoteID = Dictionary(uniqueKeysWithValues: existingUnits.compactMap { unit -> (String, PlanoraUnit)? in
            guard unit.externalSource == .manageBac, let identifier = unit.externalIdentifier else { return nil }
            return (identifier, unit)
        })
        var courseIDsByOriginalName: [String: UUID] = [:]
        var reviewCount = 0

        do {
            for record in deduplicatedCourses(snapshot.courses) {
                let normalized = ManageBacCourseNormalizer.normalize(record, curriculum: curriculum)
                let course = coursesByRemoteID[record.remoteIdentifier] ?? PlanoraCourse(
                    displayName: normalized.displayName,
                    originalName: record.name,
                    canonicalSubject: normalized.canonicalSubject,
                    level: normalized.level,
                    curriculum: normalized.curriculum,
                    externalSource: .manageBac,
                    externalIdentifier: record.remoteIdentifier
                )
                if coursesByRemoteID[record.remoteIdentifier] == nil {
                    modelContext.insert(course)
                    coursesByRemoteID[record.remoteIdentifier] = course
                }
                course.displayName = normalized.displayName
                course.originalName = record.name
                course.canonicalSubject = normalized.canonicalSubject
                course.level = normalized.level
                course.curriculum = normalized.curriculum
                course.teacherNames = record.teacherNames
                course.externalURLString = record.detailURL
                course.isArchived = false
                course.needsRemoteReview = normalized.requiresReview
                course.lastSyncDate = Date()
                courseIDsByOriginalName[normalizedKey(record.name)] = course.id
                if normalized.requiresReview { reviewCount += 1 }
            }

            for record in deduplicatedUnits(snapshot.units) {
                guard let course = coursesByRemoteID[record.courseIdentifier] else {
                    reviewCount += 1
                    continue
                }
                let unit = unitsByRemoteID[record.remoteIdentifier] ?? PlanoraUnit(
                    courseID: course.id,
                    title: record.title,
                    externalSource: .manageBac,
                    externalIdentifier: record.remoteIdentifier
                )
                if unitsByRemoteID[record.remoteIdentifier] == nil {
                    modelContext.insert(unit)
                    unitsByRemoteID[record.remoteIdentifier] = unit
                }
                unit.courseID = course.id
                unit.title = record.title
                unit.externalURLString = record.detailURL
                unit.startDate = record.startDateText.flatMap { ManageBacDateParser.date(from: $0) }
                unit.endDate = record.endDateText.flatMap { ManageBacDateParser.date(from: $0) }
                unit.officialProgress = record.officialProgress.map { min(max($0, 0), 1) }
                unit.isArchived = false
                unit.lastSyncDate = Date()
            }

            var tasksByIdentifier: [String: PlanoraTask] = [:]
            for task in existingTasks where task.externalSource == .manageBac {
                guard let identifier = task.externalIdentifier else { continue }
                tasksByIdentifier[identifier] = task
            }
            var importedCount = 0
            var updatedCount = 0
            var completedCount = 0
            let remoteTasks = deduplicatedTasks(snapshot.tasks)
            let seenIdentifiers = Set(remoteTasks.map(\.stableIdentifier))

            for record in remoteTasks {
                let identifier = record.stableIdentifier
                let task: PlanoraTask
                if let existing = tasksByIdentifier[identifier] {
                    task = existing
                    updatedCount += 1
                } else {
                    let deadline = record.deadline
                    task = PlanoraTask(
                        title: record.title,
                        subject: record.subject.isEmpty ? "ManageBac" : record.subject,
                        type: record.inferredType,
                        deadline: deadline,
                        hasDeadline: deadline != nil,
                        progressState: .percentage(0),
                        notes: "",
                        importance: TaskPriority.medium.rawValue
                    )
                    task.externalSource = .manageBac
                    task.externalIdentifier = identifier
                    modelContext.insert(task)
                    tasksByIdentifier[identifier] = task
                    importedCount += 1
                }

                applyRemoteValues(record, to: task)
                if let courseIdentifier = record.courseIdentifier, let course = coursesByRemoteID[courseIdentifier] {
                    task.courseID = course.id
                    task.subject = course.displayName
                } else if let courseID = courseIDsByOriginalName[normalizedKey(record.subject)] {
                    task.courseID = courseID
                }
                if let unitIdentifier = record.unitIdentifier {
                    task.unitID = unitsByRemoteID[unitIdentifier]?.id
                }
                if record.remoteStatus == .completed, !task.isCompleted {
                    task.setCompleted(true)
                    completedCount += 1
                }
            }

            for task in existingTasks where task.externalSource == .manageBac {
                guard let identifier = task.externalIdentifier, !seenIdentifiers.contains(identifier), !task.isArchived else { continue }
                task.needsRemoteReview = true
                reviewCount += 1
            }

            try modelContext.save()
            return ManageBacImportSummary(
                courseCount: coursesByRemoteID.count,
                unitCount: unitsByRemoteID.count,
                importedCount: importedCount,
                updatedCount: updatedCount,
                completedCount: completedCount,
                reviewCount: reviewCount
            )
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    static func importRecords(
        _ records: [ManageBacTaskRecord],
        courses: [String],
        existingTasks: [PlanoraTask],
        into modelContext: ModelContext
    ) throws -> ManageBacImportSummary {
        let courseRecords = courses.enumerated().map { index, name in
            ManageBacCourseRecord(
                remoteIdentifier: "legacy-course-\(index)-\(normalizedKey(name))",
                name: name,
                teacherNames: [],
                detailURL: nil,
                programmeText: nil
            )
        }
        return try importSnapshot(
            ManageBacSyncSnapshot(schoolHost: "", programmeText: nil, courses: courseRecords, units: [], tasks: records),
            currentCurriculum: .ib,
            existingTasks: existingTasks,
            into: modelContext
        )
    }

    private static func applyRemoteValues(_ record: ManageBacTaskRecord, to task: PlanoraTask) {
        task.title = record.title
        if !record.subject.isEmpty { task.subject = record.subject }
        task.type = record.inferredType
        task.setDeadline(record.deadline, enabled: record.deadline != nil)
        task.externalURLString = record.detailURL
        task.externalUpdatedAt = Date()
        task.remoteStatusRawValue = record.remoteStatus.rawValue
        task.needsRemoteReview = false
    }

    private static func deduplicatedTasks(_ records: [ManageBacTaskRecord]) -> [ManageBacTaskRecord] {
        var seen = Set<String>()
        return records.filter { seen.insert($0.stableIdentifier).inserted }
    }

    private static func deduplicatedCourses(_ records: [ManageBacCourseRecord]) -> [ManageBacCourseRecord] {
        var seen = Set<String>()
        return records.filter { seen.insert($0.remoteIdentifier).inserted }
    }

    private static func deduplicatedUnits(_ records: [ManageBacUnitRecord]) -> [ManageBacUnitRecord] {
        var seen = Set<String>()
        return records.filter { seen.insert($0.remoteIdentifier).inserted }
    }

    private static func normalizedKey(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}
