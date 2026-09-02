import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - File Document

struct TaskBackupDocument: FileDocument {
    static let backupType = UTType.json
    static var readableContentTypes: [UTType] { [backupType] }
    static var writableContentTypes: [UTType] { [backupType] }

    var text: String

    init(text: String = "") {
        self.text = text
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let text = String(data: data, encoding: .utf8) else {
            throw TaskBackupError.unreadableFile
        }

        self.text = text
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

// MARK: - User-Facing Errors

enum TaskBackupError: LocalizedError {
    case unreadableFile
    case wrongBackupFile
    case invalidJSONFormat
    case missingTaskData
    case emptyBackup
    case unsupportedVersion

    var alertTitle: String {
        switch self {
        case .unreadableFile:
            String(localized: "File Read Failed")
        case .wrongBackupFile:
            String(localized: "Wrong File")
        case .invalidJSONFormat:
            String(localized: "Format Error")
        case .missingTaskData, .emptyBackup:
            String(localized: "Backup Data Missing")
        case .unsupportedVersion:
            String(localized: "Unsupported Backup Version")
        }
    }

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            String(localized: "The file could not be read. Make sure it is still accessible in Files.")
        case .wrongBackupFile:
            String(localized: "This JSON file is not a Planora task backup. Choose a .json backup exported by Planora.")
        case .invalidJSONFormat:
            String(localized: "This file is not valid JSON. Choose a .json backup exported by Planora.")
        case .missingTaskData:
            String(localized: "The JSON file is readable, but its Planora task data is missing or incomplete.")
        case .emptyBackup:
            String(localized: "This backup contains no Planora data, so nothing was imported.")
        case .unsupportedVersion:
            String(localized: "Planora currently imports version 9 backups only.")
        }
    }

    static func importFailureTitle(for error: Error) -> String {
        guard let backupError = error as? TaskBackupError else {
            return String(localized: "Import Failed")
        }

        return backupError.alertTitle
    }
}

// MARK: - Encoding and Decoding

@MainActor
enum TaskBackupCodec {
    static let currentVersion = 9

    static func json(
        for tasks: [PlanoraTask],
        courses: [PlanoraCourse] = [],
        units: [PlanoraUnit] = [],
        topics: [PlanoraTopic] = [],
        assessments: [PlanoraAssessment] = []
    ) throws -> String {
        let backup = PlanoraTaskBackup(
            exportedAt: Date(),
            tasks: tasks.map(PlanoraTaskBackupItem.init(task:)),
            courses: courses.map(PlanoraCourseBackupItem.init(course:)),
            units: units.map(PlanoraUnitBackupItem.init(unit:)),
            topics: topics.map(PlanoraTopicBackupItem.init(topic:)),
            assessments: assessments.map(PlanoraAssessmentBackupItem.init(assessment:))
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let data = try encoder.encode(backup)
        guard let json = String(data: data, encoding: .utf8) else {
            throw TaskBackupError.missingTaskData
        }

        return json
    }

    static func tasks(from text: String) throws -> [PlanoraTask] {
        try content(from: text).tasks
    }

    static func content(from text: String) throws -> PlanoraBackupContent {
        let payload = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = payload.data(using: .utf8) else {
            throw TaskBackupError.unreadableFile
        }

        let jsonObject: Any

        do {
            jsonObject = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TaskBackupError.invalidJSONFormat
        }

        guard let dictionary = jsonObject as? [String: Any] else {
            throw TaskBackupError.wrongBackupFile
        }

        guard dictionary["tasks"] != nil || dictionary["version"] != nil else {
            throw TaskBackupError.wrongBackupFile
        }

        guard let version = dictionary["version"] as? Int,
              dictionary["exportedAt"] != nil,
              dictionary["tasks"] != nil else {
            throw TaskBackupError.missingTaskData
        }

        guard version == currentVersion else {
            throw TaskBackupError.unsupportedVersion
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup: PlanoraTaskBackup

        do {
            backup = try decoder.decode(PlanoraTaskBackup.self, from: data)
        } catch {
            throw TaskBackupError.missingTaskData
        }

        let content = PlanoraBackupContent(
            tasks: backup.tasks.map(\.task),
            courses: backup.courses.map(\.course),
            units: backup.units.map(\.unit),
            topics: backup.topics.map(\.topic),
            assessments: backup.assessments.map(\.assessment)
        )

        guard !content.tasks.isEmpty || !content.courses.isEmpty || !content.units.isEmpty ||
                !content.topics.isEmpty || !content.assessments.isEmpty else {
            throw TaskBackupError.emptyBackup
        }

        return content
    }
}

struct PlanoraBackupContent {
    var tasks: [PlanoraTask]
    var courses: [PlanoraCourse]
    var units: [PlanoraUnit]
    var topics: [PlanoraTopic]
    var assessments: [PlanoraAssessment]
}

// MARK: - Import

@MainActor
enum TaskBackupImporter {
    static func preview(
        from url: URL,
        existingTasks: [PlanoraTask],
        existingCourses: [PlanoraCourse] = [],
        existingUnits: [PlanoraUnit] = []
    ) throws -> TaskImportPreview {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data: Data

        do {
            data = try Data(contentsOf: url)
        } catch {
            throw TaskBackupError.unreadableFile
        }

        guard let text = String(data: data, encoding: .utf8) else {
            throw TaskBackupError.unreadableFile
        }

        let content = try TaskBackupCodec.content(from: text)
        return preview(content: content, existingTasks: existingTasks)
    }

    static func preview(tasks importedTasks: [PlanoraTask], existingTasks: [PlanoraTask]) -> TaskImportPreview {
        var index = TaskImportIndex(tasks: existingTasks)
        var duplicateCount = 0

        for task in importedTasks {
            if index.duplicate(of: task) != nil {
                duplicateCount += 1
            } else {
                index.insert(task)
            }
        }

        return TaskImportPreview(tasks: importedTasks, duplicateCount: duplicateCount)
    }

    static func preview(content: PlanoraBackupContent, existingTasks: [PlanoraTask]) -> TaskImportPreview {
        let taskPreview = preview(tasks: content.tasks, existingTasks: existingTasks)
        return TaskImportPreview(
            tasks: content.tasks,
            courses: content.courses,
            units: content.units,
            topics: content.topics,
            assessments: content.assessments,
            duplicateCount: taskPreview.duplicateCount
        )
    }

    static func importTasks(
        _ preview: TaskImportPreview,
        strategy: TaskImportStrategy,
        existingTasks: [PlanoraTask],
        existingCourses: [PlanoraCourse] = [],
        existingUnits: [PlanoraUnit] = [],
        existingTopics: [PlanoraTopic] = [],
        existingAssessments: [PlanoraAssessment] = [],
        into modelContext: ModelContext
    ) throws -> TaskImportResult {
        AutomaticTaskBackup.save(
            tasks: existingTasks,
            courses: existingCourses,
            units: existingUnits,
            topics: existingTopics,
            assessments: existingAssessments
        )
        var importIndex = TaskImportIndex(tasks: existingTasks)
        var importedCount = 0
        var skippedCount = 0
        var seriesIDMap: [UUID: UUID] = [:]

        do {
            let courseIDMap = importCourses(
                preview.courses,
                strategy: strategy,
                existing: existingCourses,
                into: modelContext
            )
            let unitIDMap = importUnits(
                preview.units,
                courseIDMap: courseIDMap,
                strategy: strategy,
                existing: existingUnits,
                into: modelContext
            )
            let topicIDMap = importTopics(
                preview.topics,
                courseIDMap: courseIDMap,
                strategy: strategy,
                existing: existingTopics,
                into: modelContext
            )
            importAssessments(
                preview.assessments,
                courseIDMap: courseIDMap,
                strategy: strategy,
                existing: existingAssessments,
                into: modelContext
            )

            for importedTask in preview.tasks {
                if let courseID = importedTask.courseID {
                    importedTask.courseID = courseIDMap[courseID] ?? courseID
                }
                if let unitID = importedTask.unitID {
                    importedTask.unitID = unitIDMap[unitID] ?? unitID
                }
                importedTask.topicIDs = importedTask.topicIDs.compactMap { topicIDMap[$0] ?? $0 }
                let duplicate = importIndex.duplicate(of: importedTask)

                switch strategy {
                case .skipDuplicates where duplicate != nil:
                    skippedCount += 1
                    continue
                case .overwriteDuplicates where duplicate != nil:
                    if let duplicate {
                        duplicate.applyImportedValues(from: importedTask)
                        importIndex.insert(duplicate)
                        importedCount += 1
                    }
                    continue
                case .importAsNew:
                    importedTask.id = UUID()
                    if let originalSeriesID = importedTask.recurrenceSeriesID {
                        let newSeriesID = seriesIDMap[originalSeriesID] ?? UUID()
                        seriesIDMap[originalSeriesID] = newSeriesID
                        importedTask.recurrenceSeriesID = newSeriesID
                    }
                default:
                    break
                }

                modelContext.insert(importedTask)
                importIndex.insert(importedTask)
                importedCount += 1
            }

            try modelContext.save()
            return TaskImportResult(importedCount: importedCount, skippedCount: skippedCount)
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    private static func importCourses(
        _ imported: [PlanoraCourse],
        strategy: TaskImportStrategy,
        existing: [PlanoraCourse],
        into modelContext: ModelContext
    ) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        var available = existing

        for course in imported {
            let originalID = course.id
            let duplicate = available.first { existingCourse in
                existingCourse.id == originalID || (
                    existingCourse.externalSourceRawValue == course.externalSourceRawValue &&
                    existingCourse.externalIdentifier != nil &&
                    existingCourse.externalIdentifier == course.externalIdentifier
                )
            }

            if let duplicate, strategy != .importAsNew {
                result[originalID] = duplicate.id
                if strategy == .overwriteDuplicates {
                    duplicate.applyImportedValues(from: course)
                }
            } else {
                if strategy == .importAsNew || duplicate != nil { course.id = UUID() }
                result[originalID] = course.id
                modelContext.insert(course)
                available.append(course)
            }
        }
        return result
    }

    private static func importUnits(
        _ imported: [PlanoraUnit],
        courseIDMap: [UUID: UUID],
        strategy: TaskImportStrategy,
        existing: [PlanoraUnit],
        into modelContext: ModelContext
    ) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        var available = existing

        for unit in imported {
            let originalID = unit.id
            unit.courseID = courseIDMap[unit.courseID] ?? unit.courseID
            let duplicate = available.first { existingUnit in
                existingUnit.id == originalID || (
                    existingUnit.externalSourceRawValue == unit.externalSourceRawValue &&
                    existingUnit.externalIdentifier != nil &&
                    existingUnit.externalIdentifier == unit.externalIdentifier
                )
            }

            if let duplicate, strategy != .importAsNew {
                result[originalID] = duplicate.id
                if strategy == .overwriteDuplicates {
                    duplicate.applyImportedValues(from: unit)
                }
            } else {
                if strategy == .importAsNew || duplicate != nil { unit.id = UUID() }
                result[originalID] = unit.id
                modelContext.insert(unit)
                available.append(unit)
            }
        }
        return result
    }

    private static func importTopics(
        _ imported: [PlanoraTopic],
        courseIDMap: [UUID: UUID],
        strategy: TaskImportStrategy,
        existing: [PlanoraTopic],
        into modelContext: ModelContext
    ) -> [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        var available = existing

        for topic in imported {
            let originalID = topic.id
            topic.courseID = topic.courseID.flatMap { courseIDMap[$0] ?? $0 }
            let duplicate = available.first {
                $0.id == originalID || ($0.subject == topic.subject && $0.title.caseInsensitiveCompare(topic.title) == .orderedSame)
            }
            if let duplicate, strategy != .importAsNew {
                result[originalID] = duplicate.id
                if strategy == .overwriteDuplicates { duplicate.applyImportedValues(from: topic) }
            } else {
                if strategy == .importAsNew || duplicate != nil { topic.id = UUID() }
                result[originalID] = topic.id
                modelContext.insert(topic)
                available.append(topic)
            }
        }
        return result
    }

    private static func importAssessments(
        _ imported: [PlanoraAssessment],
        courseIDMap: [UUID: UUID],
        strategy: TaskImportStrategy,
        existing: [PlanoraAssessment],
        into modelContext: ModelContext
    ) {
        var available = existing
        for assessment in imported {
            assessment.courseID = assessment.courseID.flatMap { courseIDMap[$0] ?? $0 }
            let duplicate = available.first {
                $0.id == assessment.id || (
                    $0.subject == assessment.subject &&
                    $0.title.caseInsensitiveCompare(assessment.title) == .orderedSame &&
                    Calendar.current.isDate($0.date, inSameDayAs: assessment.date)
                )
            }
            if let duplicate, strategy != .importAsNew {
                if strategy == .overwriteDuplicates { duplicate.applyImportedValues(from: assessment) }
            } else {
                if strategy == .importAsNew || duplicate != nil { assessment.id = UUID() }
                modelContext.insert(assessment)
                available.append(assessment)
            }
        }
    }
}

private struct TaskImportIndex {
    private var tasksByIdentity: [String: PlanoraTask] = [:]

    init(tasks: [PlanoraTask]) {
        for task in tasks {
            insert(task)
        }
    }

    mutating func insert(_ task: PlanoraTask) {
        for identity in task.importIdentityKeys {
            tasksByIdentity[identity] = task
        }
    }

    func duplicate(of task: PlanoraTask) -> PlanoraTask? {
        for identity in task.importIdentityKeys {
            if let existing = tasksByIdentity[identity] {
                return existing
            }
        }
        return nil
    }
}

struct TaskImportPreview: Identifiable {
    let id = UUID()
    let tasks: [PlanoraTask]
    let courses: [PlanoraCourse]
    let units: [PlanoraUnit]
    let topics: [PlanoraTopic]
    let assessments: [PlanoraAssessment]
    let duplicateCount: Int

    init(
        tasks: [PlanoraTask],
        courses: [PlanoraCourse] = [],
        units: [PlanoraUnit] = [],
        topics: [PlanoraTopic] = [],
        assessments: [PlanoraAssessment] = [],
        duplicateCount: Int
    ) {
        self.tasks = tasks
        self.courses = courses
        self.units = units
        self.topics = topics
        self.assessments = assessments
        self.duplicateCount = duplicateCount
    }
}

enum TaskImportStrategy: Equatable {
    case skipDuplicates
    case overwriteDuplicates
    case importAsNew
}

struct TaskImportResult {
    let importedCount: Int
    let skippedCount: Int
}

@MainActor
enum AutomaticTaskBackup {
    private static let key = "planora.automaticTaskBackup"

    static func save(
        tasks: [PlanoraTask],
        courses: [PlanoraCourse] = [],
        units: [PlanoraUnit] = [],
        topics: [PlanoraTopic] = [],
        assessments: [PlanoraAssessment] = []
    ) {
        guard let json = try? TaskBackupCodec.json(
            for: tasks,
            courses: courses,
            units: units,
            topics: topics,
            assessments: assessments
        ) else { return }
        UserDefaults.standard.set(json, forKey: key)
    }

    static func tasks() throws -> [PlanoraTask] {
        try content().tasks
    }

    static func content() throws -> PlanoraBackupContent {
        guard let json = UserDefaults.standard.string(forKey: key) else {
            throw TaskBackupError.emptyBackup
        }
        return try TaskBackupCodec.content(from: json)
    }

    static var isAvailable: Bool {
        UserDefaults.standard.string(forKey: key) != nil
    }
}

// MARK: - Backup Payload

private struct PlanoraTaskBackup: Codable {
    var version = TaskBackupCodec.currentVersion
    var exportedAt: Date
    var tasks: [PlanoraTaskBackupItem]
    var courses: [PlanoraCourseBackupItem]
    var units: [PlanoraUnitBackupItem]
    var topics: [PlanoraTopicBackupItem] = []
    var assessments: [PlanoraAssessmentBackupItem] = []

    init(
        exportedAt: Date,
        tasks: [PlanoraTaskBackupItem],
        courses: [PlanoraCourseBackupItem],
        units: [PlanoraUnitBackupItem],
        topics: [PlanoraTopicBackupItem],
        assessments: [PlanoraAssessmentBackupItem]
    ) {
        self.exportedAt = exportedAt
        self.tasks = tasks
        self.courses = courses
        self.units = units
        self.topics = topics
        self.assessments = assessments
    }

}

private struct PlanoraTaskBackupItem: Codable {
    var id: UUID
    var title: String
    var subject: String
    var typeRawValue: String
    var deadline: Date?
    var hasDeadline: Bool
    var tracksProgress: Bool
    var progressKindRawValue: String
    var percentageProgress: Double
    var stageName: String
    var notes: String
    var createdDate: Date
    var isCompleted: Bool
    var completedDate: Date?
    var isPinned: Bool?
    var importance: Int
    var timelineData: Data?
    var reminderData: Data?
    var recurrenceData: Data?
    var recurrenceSeriesID: UUID?
    var recurrenceSequence: Int
    var recurrenceOccurrenceDate: Date?
    var plannedDate: Date?
    var deadlineDayIdentifier: String?
    var plannedDayIdentifier: String?
    var externalSourceRawValue: String?
    var externalIdentifier: String?
    var externalURLString: String?
    var externalUpdatedAt: Date?
    var courseID: UUID?
    var unitID: UUID?
    var remoteStatusRawValue: String?
    var needsRemoteReview: Bool
    var archivedDate: Date?
    var deletedDate: Date?
    var estimatedMinutes: Int?
    var actualMinutes: Int?
    var usesSubtasksForProgress: Bool?
    var subtasks: [PlanoraSubtaskBackupItem]?
    var resourceLinks: [PlanoraResourceLinkBackupItem]?
    var topicIDs: [UUID]?
    var examScope: String?
    var targetScore: Double?
    var pastPaperTarget: Int?
    var pastPapersCompleted: Int?

    init(task: PlanoraTask) {
        id = task.id
        title = task.title
        subject = task.subject
        typeRawValue = task.type.rawValue
        deadline = task.deadline
        hasDeadline = task.hasDeadline
        tracksProgress = task.tracksProgress
        progressKindRawValue = task.progressKindRawValue
        percentageProgress = task.percentageProgress
        stageName = task.stageName
        notes = task.notes
        createdDate = task.createdDate
        isCompleted = task.isCompleted
        completedDate = task.completedDate
        isPinned = task.isPinned
        importance = task.importance
        timelineData = task.timelineData
        reminderData = task.reminderData
        recurrenceData = task.recurrenceData
        recurrenceSeriesID = task.recurrenceSeriesID
        recurrenceSequence = task.recurrenceSequence
        recurrenceOccurrenceDate = task.recurrenceOccurrenceDate
        plannedDate = task.plannedDate
        deadlineDayIdentifier = task.deadlineDayIdentifier
        plannedDayIdentifier = task.plannedDayIdentifier
        externalSourceRawValue = task.externalSourceRawValue
        externalIdentifier = task.externalIdentifier
        externalURLString = task.externalURLString
        externalUpdatedAt = task.externalUpdatedAt
        courseID = task.courseID
        unitID = task.unitID
        remoteStatusRawValue = task.remoteStatusRawValue
        needsRemoteReview = task.needsRemoteReview
        archivedDate = task.archivedDate
        deletedDate = task.deletedDate
        estimatedMinutes = task.estimatedMinutes
        actualMinutes = task.actualMinutes
        usesSubtasksForProgress = task.usesSubtasksForProgress
        subtasks = task.subtasks.sorted { $0.sortOrder < $1.sortOrder }.map(PlanoraSubtaskBackupItem.init)
        resourceLinks = task.resourceLinks.sorted { $0.createdDate < $1.createdDate }.map(PlanoraResourceLinkBackupItem.init)
        topicIDs = task.topicIDs
        examScope = task.examScope
        targetScore = task.targetScore
        pastPaperTarget = task.pastPaperTarget
        pastPapersCompleted = task.pastPapersCompleted
    }

    var task: PlanoraTask {
        let type = TaskType(rawValue: typeRawValue) ?? .custom
        let progressKind = ProgressKind(rawValue: progressKindRawValue) ?? .percentage
        let progressState: ProgressState

        switch progressKind {
        case .percentage:
            progressState = .percentage(percentageProgress)
        case .stage:
            progressState = .stage(stageName)
        }

        let restoredTask = PlanoraTask(
            id: id,
            title: title,
            subject: subject,
            type: type,
            deadline: deadline,
            hasDeadline: hasDeadline,
            tracksProgress: tracksProgress,
            progressState: progressState,
            notes: notes,
            createdDate: createdDate,
            isCompleted: isCompleted,
            completedDate: completedDate,
            importance: importance,
            plannedDate: plannedDate
        )

        if let timelineData {
            restoredTask.timelineData = timelineData
        } else if isCompleted {
            restoredTask.setCompleted(true)
        }

        // Reminder configuration is restored, but import never schedules notifications.
        // This prevents repeated imports from creating duplicate pending requests.
        restoredTask.reminderData = reminderData
        restoredTask.isPinned = isPinned ?? false
        restoredTask.recurrenceData = recurrenceData
        restoredTask.recurrenceSeriesID = recurrenceSeriesID
        restoredTask.recurrenceSequence = recurrenceSequence
        restoredTask.recurrenceOccurrenceDate = recurrenceOccurrenceDate
        restoredTask.deadlineDayIdentifier = deadlineDayIdentifier
        restoredTask.plannedDayIdentifier = plannedDayIdentifier
        restoredTask.externalSourceRawValue = externalSourceRawValue
        restoredTask.externalIdentifier = externalIdentifier
        restoredTask.externalURLString = externalURLString
        restoredTask.externalUpdatedAt = externalUpdatedAt
        restoredTask.courseID = courseID
        restoredTask.unitID = unitID
        restoredTask.remoteStatusRawValue = remoteStatusRawValue
        restoredTask.needsRemoteReview = needsRemoteReview
        restoredTask.archivedDate = archivedDate
        restoredTask.deletedDate = deletedDate
        restoredTask.estimatedMinutes = max(estimatedMinutes ?? 0, 0)
        restoredTask.actualMinutes = max(actualMinutes ?? 0, 0)
        restoredTask.usesSubtasksForProgress = usesSubtasksForProgress ?? false
        restoredTask.subtasks = (subtasks ?? []).map { $0.model(task: restoredTask) }
        restoredTask.resourceLinks = (resourceLinks ?? []).map { $0.model(task: restoredTask) }
        restoredTask.topicIDs = topicIDs ?? []
        restoredTask.examScope = examScope ?? ""
        restoredTask.targetScore = targetScore
        restoredTask.pastPaperTarget = max(pastPaperTarget ?? 0, 0)
        restoredTask.pastPapersCompleted = min(max(pastPapersCompleted ?? 0, 0), restoredTask.pastPaperTarget)
        restoredTask.normalizeCalendarDates()

        return restoredTask
    }
}

private struct PlanoraTopicBackupItem: Codable {
    var id: UUID
    var subject: String
    var title: String
    var mastery: Double
    var notes: String
    var courseID: UUID?
    var createdDate: Date

    init(topic: PlanoraTopic) {
        id = topic.id
        subject = topic.subject
        title = topic.title
        mastery = topic.mastery
        notes = topic.notes
        courseID = topic.courseID
        createdDate = topic.createdDate
    }

    var topic: PlanoraTopic {
        PlanoraTopic(id: id, subject: subject, title: title, mastery: mastery, notes: notes, courseID: courseID, createdDate: createdDate)
    }
}

private struct PlanoraAssessmentBackupItem: Codable {
    var id: UUID
    var title: String
    var subject: String
    var earnedScore: Double
    var maximumScore: Double
    var date: Date
    var typeRawValue: String
    var notes: String
    var courseID: UUID?
    var createdDate: Date

    init(assessment: PlanoraAssessment) {
        id = assessment.id
        title = assessment.title
        subject = assessment.subject
        earnedScore = assessment.earnedScore
        maximumScore = assessment.maximumScore
        date = assessment.date
        typeRawValue = assessment.typeRawValue
        notes = assessment.notes
        courseID = assessment.courseID
        createdDate = assessment.createdDate
    }

    var assessment: PlanoraAssessment {
        PlanoraAssessment(
            id: id,
            title: title,
            subject: subject,
            earnedScore: earnedScore,
            maximumScore: maximumScore,
            date: date,
            type: AssessmentType(rawValue: typeRawValue) ?? .other,
            notes: notes,
            courseID: courseID,
            createdDate: createdDate
        )
    }
}

private struct PlanoraSubtaskBackupItem: Codable {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var targetDate: Date?
    var estimatedMinutes: Int
    var createdDate: Date

    init(_ subtask: PlanoraSubtask) {
        id = subtask.id
        title = subtask.title
        isCompleted = subtask.isCompleted
        sortOrder = subtask.sortOrder
        targetDate = subtask.targetDate
        estimatedMinutes = subtask.estimatedMinutes
        createdDate = subtask.createdDate
    }

    func model(task: PlanoraTask) -> PlanoraSubtask {
        PlanoraSubtask(
            id: id,
            title: title,
            isCompleted: isCompleted,
            sortOrder: sortOrder,
            targetDate: targetDate,
            estimatedMinutes: estimatedMinutes,
            createdDate: createdDate,
            task: task
        )
    }
}

private struct PlanoraResourceLinkBackupItem: Codable {
    var id: UUID
    var title: String
    var urlString: String
    var createdDate: Date

    init(_ resource: PlanoraResourceLink) {
        id = resource.id
        title = resource.title
        urlString = resource.urlString
        createdDate = resource.createdDate
    }

    func model(task: PlanoraTask) -> PlanoraResourceLink {
        PlanoraResourceLink(id: id, title: title, urlString: urlString, createdDate: createdDate, task: task)
    }
}

private struct PlanoraCourseBackupItem: Codable {
    var id: UUID
    var displayName: String
    var originalName: String
    var canonicalSubject: String
    var levelRawValue: String?
    var curriculumRawValue: String
    var teacherNames: [String]
    var externalSourceRawValue: String?
    var externalIdentifier: String?
    var externalURLString: String?
    var isArchived: Bool
    var needsRemoteReview: Bool
    var lastSyncDate: Date?

    init(course: PlanoraCourse) {
        id = course.id
        displayName = course.displayName
        originalName = course.originalName
        canonicalSubject = course.canonicalSubject
        levelRawValue = course.levelRawValue
        curriculumRawValue = course.curriculumRawValue
        teacherNames = course.teacherNames
        externalSourceRawValue = course.externalSourceRawValue
        externalIdentifier = course.externalIdentifier
        externalURLString = course.externalURLString
        isArchived = course.isArchived
        needsRemoteReview = course.needsRemoteReview
        lastSyncDate = course.lastSyncDate
    }

    var course: PlanoraCourse {
        PlanoraCourse(
            id: id,
            displayName: displayName,
            originalName: originalName,
            canonicalSubject: canonicalSubject,
            level: levelRawValue.flatMap(CourseLevel.init(rawValue:)),
            curriculum: Curriculum(rawValue: curriculumRawValue) ?? .ib,
            teacherNames: teacherNames,
            externalSource: externalSourceRawValue.flatMap(ExternalTaskSource.init(rawValue:)),
            externalIdentifier: externalIdentifier,
            externalURLString: externalURLString,
            isArchived: isArchived,
            needsRemoteReview: needsRemoteReview,
            lastSyncDate: lastSyncDate
        )
    }
}

private struct PlanoraUnitBackupItem: Codable {
    var id: UUID
    var courseID: UUID
    var title: String
    var externalSourceRawValue: String?
    var externalIdentifier: String?
    var externalURLString: String?
    var startDate: Date?
    var endDate: Date?
    var officialProgress: Double?
    var isArchived: Bool
    var lastSyncDate: Date?

    init(unit: PlanoraUnit) {
        id = unit.id
        courseID = unit.courseID
        title = unit.title
        externalSourceRawValue = unit.externalSourceRawValue
        externalIdentifier = unit.externalIdentifier
        externalURLString = unit.externalURLString
        startDate = unit.startDate
        endDate = unit.endDate
        officialProgress = unit.officialProgress
        isArchived = unit.isArchived
        lastSyncDate = unit.lastSyncDate
    }

    var unit: PlanoraUnit {
        PlanoraUnit(
            id: id,
            courseID: courseID,
            title: title,
            externalSource: externalSourceRawValue.flatMap(ExternalTaskSource.init(rawValue:)),
            externalIdentifier: externalIdentifier,
            externalURLString: externalURLString,
            startDate: startDate,
            endDate: endDate,
            officialProgress: officialProgress,
            isArchived: isArchived,
            lastSyncDate: lastSyncDate
        )
    }
}

private extension PlanoraTask {
    var importIdentityKeys: [String] {
        var keys = [
            "id:\(id.uuidString)",
            "task:\(importFingerprint)"
        ]

        if let externalSourceRawValue, let externalIdentifier {
            keys.insert("external:\(externalSourceRawValue):\(externalIdentifier)", at: 0)
        }

        if isRecurring, let occurrenceDayIdentifier {
            keys.append(
                [
                    "recurring",
                    normalizedImportText(title),
                    normalizedImportText(subject),
                    type.rawValue,
                    occurrenceDayIdentifier
                ].joined(separator: "|")
            )
        }

        return keys
    }

    var occurrenceDayIdentifier: String? {
        if let deadlineDayIdentifier {
            return deadlineDayIdentifier
        }
        if let recurrenceOccurrenceDate {
            return PlanoraCalendarDay(date: recurrenceOccurrenceDate).identifier
        }
        if let deadline {
            return PlanoraCalendarDay(date: deadline).identifier
        }
        return nil
    }

    var importFingerprint: String {
        [
            normalizedImportText(title),
            normalizedImportText(subject),
            type.rawValue,
            deadline.map { String(Int($0.timeIntervalSince1970 / 60)) } ?? "none",
            String(Int(createdDate.timeIntervalSince1970 / 60))
        ].joined(separator: "|")
    }

    func normalizedImportText(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }

    func applyImportedValues(from source: PlanoraTask) {
        title = source.title
        subject = source.subject
        typeRawValue = source.type.rawValue
        setDeadline(source.deadline, enabled: source.hasDeadline)
        setPlannedDate(source.plannedDate)
        deadlineDayIdentifier = source.deadlineDayIdentifier
        plannedDayIdentifier = source.plannedDayIdentifier
        tracksProgress = source.tracksProgress
        progressKindRawValue = source.progressKindRawValue
        percentageProgress = source.percentageProgress
        stageName = source.stageName
        notes = source.notes
        createdDate = source.createdDate
        isCompleted = source.isCompleted
        completedDate = source.completedDate
        importance = source.importance
        timelineData = source.timelineData
        reminderData = source.reminderData
        recurrenceData = source.recurrenceData
        recurrenceSeriesID = source.recurrenceSeriesID
        recurrenceSequence = source.recurrenceSequence
        recurrenceOccurrenceDate = source.recurrenceOccurrenceDate
        externalSourceRawValue = source.externalSourceRawValue
        externalIdentifier = source.externalIdentifier
        externalURLString = source.externalURLString
        externalUpdatedAt = source.externalUpdatedAt
        isPinned = source.isPinned
        archivedDate = source.archivedDate
        deletedDate = source.deletedDate
        estimatedMinutes = source.estimatedMinutes
        actualMinutes = source.actualMinutes
        usesSubtasksForProgress = source.usesSubtasksForProgress
        topicIDs = source.topicIDs
        examScope = source.examScope
        targetScore = source.targetScore
        pastPaperTarget = source.pastPaperTarget
        pastPapersCompleted = source.pastPapersCompleted
        subtasks = source.subtasks.enumerated().map { index, item in
            PlanoraSubtask(
                title: item.title,
                isCompleted: item.isCompleted,
                sortOrder: index,
                targetDate: item.targetDate,
                estimatedMinutes: item.estimatedMinutes,
                createdDate: item.createdDate,
                task: self
            )
        }
        resourceLinks = source.resourceLinks.map {
            PlanoraResourceLink(title: $0.title, urlString: $0.urlString, createdDate: $0.createdDate, task: self)
        }
        normalizeCalendarDates()
    }
}

private extension PlanoraTopic {
    func applyImportedValues(from source: PlanoraTopic) {
        subject = source.subject
        title = source.title
        mastery = min(max(source.mastery, 0), 1)
        notes = source.notes
        courseID = source.courseID
        createdDate = source.createdDate
    }
}

private extension PlanoraAssessment {
    func applyImportedValues(from source: PlanoraAssessment) {
        title = source.title
        subject = source.subject
        earnedScore = max(source.earnedScore, 0)
        maximumScore = max(source.maximumScore, 0.01)
        date = source.date
        typeRawValue = source.typeRawValue
        notes = source.notes
        courseID = source.courseID
        createdDate = source.createdDate
    }
}
