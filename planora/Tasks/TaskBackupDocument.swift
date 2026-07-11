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

    var alertTitle: String {
        switch self {
        case .unreadableFile:
            L("文件读取失败", "File Read Failed")
        case .wrongBackupFile:
            L("文件错误", "Wrong File")
        case .invalidJSONFormat:
            L("格式错误", "Format Error")
        case .missingTaskData, .emptyBackup:
            L("备份数据缺失", "Backup Data Missing")
        }
    }

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            L("文件无法读取。请确认它仍在文件 App 中可访问。", "The file could not be read. Make sure it is still accessible in Files.")
        case .wrongBackupFile:
            L("这个 JSON 文件不是 Planora 任务备份。请选择 Planora 导出的 .json 备份文件。", "This JSON file is not a Planora task backup. Choose a .json backup exported by Planora.")
        case .invalidJSONFormat:
            L("这个文件不是有效的 JSON。请选择 Planora 导出的 .json 备份文件。", "This file is not valid JSON. Choose a .json backup exported by Planora.")
        case .missingTaskData:
            L("JSON 文件可以读取，但其中的 Planora 任务数据缺失或不完整。", "The JSON file is readable, but its Planora task data is missing or incomplete.")
        case .emptyBackup:
            L("这个备份中没有任务，因此没有导入任何内容。", "This backup contains no tasks, so nothing was imported.")
        }
    }

    static func importFailureTitle(for error: Error) -> String {
        guard let backupError = error as? TaskBackupError else {
            return L("导入失败", "Import Failed")
        }

        return backupError.alertTitle
    }
}

// MARK: - Encoding and Decoding

@MainActor
enum TaskBackupCodec {
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

        // Keep these branches distinct so the UI can tell users whether the file is
        // malformed JSON, a valid but unrelated JSON file, or an incomplete backup.
        let hasTasksPayload = dictionary["tasks"] != nil
        let hasPlanoraMetadata = dictionary["exportedAt"] != nil && dictionary["version"] != nil

        guard hasTasksPayload || hasPlanoraMetadata else {
            throw TaskBackupError.wrongBackupFile
        }

        guard hasTasksPayload else {
            throw TaskBackupError.missingTaskData
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
    var version = 8
    var exportedAt: Date
    var tasks: [PlanoraTaskBackupItem]

    init(exportedAt: Date, tasks: [PlanoraTaskBackupItem]) {
        self.exportedAt = exportedAt
        self.tasks = tasks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        exportedAt = try container.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date(timeIntervalSince1970: 0)
        tasks = try container.decode([PlanoraTaskBackupItem].self, forKey: .tasks)
    }
}

private struct PlanoraTaskBackupItem: Codable {
    var id: UUID?
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
    var recurrenceSequence: Int?
    var recurrenceOccurrenceDate: Date?
    var plannedDate: Date?
    var deadlineDayIdentifier: String?
    var plannedDayIdentifier: String?

    init(task: PlanoraTask) {
        id = task.id
        title = task.title
        subject = task.subject
        typeRawValue = task.typeRawValue
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? "General"
        typeRawValue = try container.decodeIfPresent(String.self, forKey: .typeRawValue) ?? TaskType.custom.rawValue
        deadline = try container.decodeIfPresent(Date.self, forKey: .deadline)
        hasDeadline = try container.decodeIfPresent(Bool.self, forKey: .hasDeadline) ?? (deadline != nil)
        tracksProgress = try container.decodeIfPresent(Bool.self, forKey: .tracksProgress) ?? true
        progressKindRawValue = try container.decodeIfPresent(String.self, forKey: .progressKindRawValue) ?? ProgressKind.percentage.rawValue
        percentageProgress = try container.decodeIfPresent(Double.self, forKey: .percentageProgress) ?? 0
        stageName = try container.decodeIfPresent(String.self, forKey: .stageName) ?? ""
        notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdDate = try container.decodeIfPresent(Date.self, forKey: .createdDate) ?? Date(timeIntervalSince1970: 0)
        isCompleted = try container.decodeIfPresent(Bool.self, forKey: .isCompleted) ?? false
        completedDate = try container.decodeIfPresent(Date.self, forKey: .completedDate)
        importance = try container.decodeIfPresent(Int.self, forKey: .importance) ?? TaskPriority.medium.rawValue
        timelineData = try container.decodeIfPresent(Data.self, forKey: .timelineData)
        reminderData = try container.decodeIfPresent(Data.self, forKey: .reminderData)
        recurrenceData = try container.decodeIfPresent(Data.self, forKey: .recurrenceData)
        recurrenceSeriesID = try container.decodeIfPresent(UUID.self, forKey: .recurrenceSeriesID)
        recurrenceSequence = try container.decodeIfPresent(Int.self, forKey: .recurrenceSequence)
        recurrenceOccurrenceDate = try container.decodeIfPresent(Date.self, forKey: .recurrenceOccurrenceDate)
        plannedDate = try container.decodeIfPresent(Date.self, forKey: .plannedDate)
        deadlineDayIdentifier = try container.decodeIfPresent(String.self, forKey: .deadlineDayIdentifier)
        plannedDayIdentifier = try container.decodeIfPresent(String.self, forKey: .plannedDayIdentifier)
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
            id: id ?? UUID(),
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
        restoredTask.recurrenceSequence = recurrenceSequence ?? 0
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
                    typeRawValue,
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
            typeRawValue,
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
        typeRawValue = source.typeRawValue
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
