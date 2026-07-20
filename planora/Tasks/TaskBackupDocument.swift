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
            String(localized: "This backup contains no tasks, so nothing was imported.")
        case .unsupportedVersion:
            String(localized: "Planora currently imports version 8 backups only.")
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
    static let currentVersion = 8

    static func json(for tasks: [PlanoraTask]) throws -> String {
        let backup = PlanoraTaskBackup(
            exportedAt: Date(),
            tasks: tasks.map(PlanoraTaskBackupItem.init(task:))
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

        let tasks = backup.tasks.map(\.task)

        guard !tasks.isEmpty else {
            throw TaskBackupError.emptyBackup
        }

        return tasks
    }
}

// MARK: - Import

@MainActor
enum TaskBackupImporter {
    static func preview(from url: URL, existingTasks: [PlanoraTask]) throws -> TaskImportPreview {
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

        let importedTasks = try TaskBackupCodec.tasks(from: text)
        return preview(tasks: importedTasks, existingTasks: existingTasks)
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

    static func importTasks(
        _ preview: TaskImportPreview,
        strategy: TaskImportStrategy,
        existingTasks: [PlanoraTask],
        into modelContext: ModelContext
    ) throws -> TaskImportResult {
        AutomaticTaskBackup.save(tasks: existingTasks)
        var importIndex = TaskImportIndex(tasks: existingTasks)
        var importedCount = 0
        var skippedCount = 0
        var seriesIDMap: [UUID: UUID] = [:]

        do {
            for importedTask in preview.tasks {
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
    let duplicateCount: Int
}

enum TaskImportStrategy {
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

    static func save(tasks: [PlanoraTask]) {
        guard let json = try? TaskBackupCodec.json(for: tasks) else { return }
        UserDefaults.standard.set(json, forKey: key)
    }

    static func tasks() throws -> [PlanoraTask] {
        guard let json = UserDefaults.standard.string(forKey: key) else {
            throw TaskBackupError.emptyBackup
        }
        return try TaskBackupCodec.tasks(from: json)
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

    init(exportedAt: Date, tasks: [PlanoraTaskBackupItem]) {
        self.exportedAt = exportedAt
        self.tasks = tasks
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
        restoredTask.recurrenceData = recurrenceData
        restoredTask.recurrenceSeriesID = recurrenceSeriesID
        restoredTask.recurrenceSequence = recurrenceSequence
        restoredTask.recurrenceOccurrenceDate = recurrenceOccurrenceDate
        restoredTask.deadlineDayIdentifier = deadlineDayIdentifier
        restoredTask.plannedDayIdentifier = plannedDayIdentifier
        restoredTask.normalizeCalendarDates()

        return restoredTask
    }
}

private extension PlanoraTask {
    var importIdentityKeys: [String] {
        var keys = [
            "id:\(id.uuidString)",
            "task:\(importFingerprint)"
        ]

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
        normalizeCalendarDates()
    }
}
