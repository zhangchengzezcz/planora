import Foundation
import SwiftData
import SwiftUI

// MARK: - SwiftData Model

@Model
final class PlanoraTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var subject: String
    var typeRawValue: String
    var deadline: Date?
    var hasDeadline: Bool
    var tracksProgress: Bool = true
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
    var recurrenceSequence: Int = 0
    var recurrenceOccurrenceDate: Date?
    var plannedDate: Date?
    var deadlineDayIdentifier: String?
    var plannedDayIdentifier: String?

    init(
        id: UUID = UUID(),
        title: String,
        subject: String,
        type: TaskType,
        deadline: Date?,
        hasDeadline: Bool,
        tracksProgress: Bool = true,
        progressState: ProgressState,
        notes: String,
        createdDate: Date = Date(),
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        importance: Int = 0,
        plannedDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.typeRawValue = type.rawValue
        self.deadline = hasDeadline ? deadline : nil
        self.hasDeadline = hasDeadline
        self.deadlineDayIdentifier = hasDeadline ? deadline.map { PlanoraCalendarDay(date: $0).identifier } : nil
        self.tracksProgress = tracksProgress
        self.progressKindRawValue = progressState.kind.rawValue
        self.percentageProgress = progressState.percentageValue ?? 0
        self.stageName = progressState.stageValue ?? type.defaultStage
        self.notes = notes
        self.createdDate = createdDate
        self.isCompleted = isCompleted
        self.completedDate = isCompleted ? completedDate : nil
        self.importance = importance
        self.reminderData = nil
        self.recurrenceData = nil
        self.recurrenceSeriesID = nil
        self.recurrenceSequence = 0
        self.recurrenceOccurrenceDate = nil
        self.plannedDate = plannedDate
        self.plannedDayIdentifier = plannedDate.map { PlanoraCalendarDay(date: $0).identifier }
        if progressState.kind == .stage {
            self.timelineData = AcademicMilestone.encodedDefaults(
                for: type,
                createdDate: createdDate,
                deadline: hasDeadline ? deadline : nil
            )
        } else {
            self.timelineData = nil
        }
    }

    // SwiftData persists enum raw values; these typed wrappers keep UI code safer.
    var type: TaskType {
        get { TaskType(rawValue: typeRawValue) ?? .custom }
        set { typeRawValue = newValue.rawValue }
    }

    var progressState: ProgressState {
        get {
            switch ProgressKind(rawValue: progressKindRawValue) ?? .percentage {
            case .percentage:
                return .percentage(percentageProgress)
            case .stage:
                return .stage(stageName)
            }
        }
        set {
            progressKindRawValue = newValue.kind.rawValue
            switch newValue {
            case .percentage(let value):
                percentageProgress = min(max(value, 0), 1)
            case .stage(let stage):
                stageName = stage
            }
        }
    }

    var priority: TaskPriority {
        get { TaskPriority(rawValue: importance) ?? .medium }
        set { importance = newValue.rawValue }
    }

    var timeline: [AcademicMilestone] {
        get {
            guard let timelineData,
                  let milestones = try? JSONDecoder().decode([AcademicMilestone].self, from: timelineData) else {
                return AcademicMilestone.defaults(for: type, createdDate: createdDate, deadline: deadline)
            }
            return milestones
        }
        set {
            timelineData = try? JSONEncoder().encode(newValue)
        }
    }

    var reminders: [TaskReminder] {
        get {
            guard let reminderData,
                  let reminders = try? JSONDecoder().decode([TaskReminder].self, from: reminderData) else {
                return []
            }
            return reminders
        }
        set {
            let normalized = TaskReminder.deduplicated(newValue)
            reminderData = normalized.isEmpty ? nil : try? JSONEncoder().encode(normalized)
        }
    }

    var reminderSummary: String {
        reminders.isEmpty
            ? String(localized: "Not Set")
            : PlanoraLocalization.format(String(localized: "reminder_count_format"), reminders.count)
    }

    func replaceReminders(with reminders: [TaskReminder]) {
        self.reminders = reminders
    }

    var recurrenceRule: TaskRecurrenceRule? {
        get {
            guard let recurrenceData else { return nil }
            return try? JSONDecoder().decode(TaskRecurrenceRule.self, from: recurrenceData)
        }
        set {
            recurrenceData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }

    @MainActor var recurrenceSummary: String {
        recurrenceRule?.summary ?? String(localized: "Does Not Repeat")
    }

    var isRecurring: Bool {
        recurrenceSeriesID != nil && recurrenceRule != nil
    }

    func setDeadline(_ date: Date?, enabled: Bool, calendar: Calendar = .current) {
        hasDeadline = enabled
        deadline = enabled ? date : nil
        deadlineDayIdentifier = enabled ? date.map { PlanoraCalendarDay(date: $0, calendar: calendar).identifier } : nil
    }

    func setPlannedDate(_ date: Date?, calendar: Calendar = .current) {
        plannedDate = date
        plannedDayIdentifier = date.map { PlanoraCalendarDay(date: $0, calendar: calendar).identifier }
    }

    @discardableResult
    func normalizeCalendarDates(calendar: Calendar = .current) -> Bool {
        var didChange = false

        if hasDeadline, let deadline {
            let day = deadlineDayIdentifier.flatMap { PlanoraCalendarDay(identifier: $0) }
                ?? PlanoraCalendarDay(date: deadline, calendar: calendar)
            let normalizedDate = day.date(calendar: calendar)
            if deadlineDayIdentifier != day.identifier {
                deadlineDayIdentifier = day.identifier
                didChange = true
            }
            if self.deadline != normalizedDate {
                self.deadline = normalizedDate
                didChange = true
            }
        } else {
            if deadline != nil {
                deadline = nil
                didChange = true
            }
            if deadlineDayIdentifier != nil {
                deadlineDayIdentifier = nil
                didChange = true
            }
        }

        if let plannedDate {
            let day = plannedDayIdentifier.flatMap { PlanoraCalendarDay(identifier: $0) }
                ?? PlanoraCalendarDay(date: plannedDate, calendar: calendar)
            let normalizedDate = day.date(calendar: calendar)
            if plannedDayIdentifier != day.identifier {
                plannedDayIdentifier = day.identifier
                didChange = true
            }
            if self.plannedDate != normalizedDate {
                self.plannedDate = normalizedDate
                didChange = true
            }
        } else if plannedDayIdentifier != nil {
            plannedDayIdentifier = nil
            didChange = true
        }

        return didChange
    }

    var progressFraction: Double {
        if isCompleted { return 1 }

        if let percentage = progressState.percentageValue {
            return percentage
        }

        let milestones = timeline
        guard !milestones.isEmpty else { return 0 }
        return Double(milestones.filter(\.isCompleted).count) / Double(milestones.count)
    }

    func ensureTimeline() {
        guard tracksProgress, progressState.kind == .stage, timelineData == nil else { return }
        var milestones = AcademicMilestone.defaults(for: type, createdDate: createdDate, deadline: deadline)

        if isCompleted {
            for index in milestones.indices {
                milestones[index].isCompleted = true
            }
        } else if let currentIndex = milestones.firstIndex(where: { $0.title == stageName }) {
            for index in milestones.indices where index < currentIndex {
                milestones[index].isCompleted = true
            }
        }

        timeline = milestones
        synchronizeProgress(with: milestones)
    }

    func toggleMilestone(id: UUID) {
        var milestones = timeline
        guard let selectedIndex = milestones.firstIndex(where: { $0.id == id }) else { return }

        if milestones[selectedIndex].isCompleted {
            for index in selectedIndex..<milestones.count {
                milestones[index].isCompleted = false
            }
        } else {
            for index in 0...selectedIndex {
                milestones[index].isCompleted = true
            }
        }

        timeline = milestones
        synchronizeProgress(with: milestones)
    }

    func setCompleted(_ completed: Bool) {
        if completed != isCompleted {
            completedDate = completed ? Date() : nil
        }
        isCompleted = completed

        guard tracksProgress, progressState.kind == .stage else { return }
        var milestones = timeline
        guard !milestones.isEmpty else { return }

        if completed {
            for index in milestones.indices {
                milestones[index].isCompleted = true
            }
        } else if milestones.allSatisfy(\.isCompleted), let lastIndex = milestones.indices.last {
            milestones[lastIndex].isCompleted = false
        }

        timeline = milestones
        synchronizeProgress(with: milestones)
    }

    func setCurrentStage(_ stage: String) {
        var milestones = timeline
        guard let currentIndex = milestones.firstIndex(where: { $0.title == stage }) else {
            stageName = stage
            return
        }

        for index in milestones.indices {
            milestones[index].isCompleted = index < currentIndex
        }

        timeline = milestones
        synchronizeProgress(with: milestones)
    }

    func rebuildTimeline(preservingCompletion: Bool) {
        let completedTitles = preservingCompletion
            ? Set(timeline.filter(\.isCompleted).map(\.title))
            : []
        var milestones = AcademicMilestone.defaults(for: type, createdDate: createdDate, deadline: deadline)

        if preservingCompletion {
            for index in milestones.indices {
                milestones[index].isCompleted = completedTitles.contains(milestones[index].title)
            }
        }

        timeline = milestones
        synchronizeProgress(with: milestones)
    }

    func replaceTimeline(with milestones: [AcademicMilestone]) {
        guard !milestones.isEmpty else { return }
        timeline = milestones
        synchronizeProgress(with: milestones)
    }

    func clampTimelineDatesToDeadline() {
        guard hasDeadline, let deadline else { return }
        let allowedRange = min(createdDate, deadline)...max(createdDate, deadline)
        var milestones = timeline

        for index in milestones.indices {
            guard let targetDate = milestones[index].targetDate else { continue }
            milestones[index].targetDate = min(max(targetDate, allowedRange.lowerBound), allowedRange.upperBound)
        }

        timeline = milestones
    }

    private func synchronizeProgress(with milestones: [AcademicMilestone]) {
        guard !milestones.isEmpty else { return }

        let timelineIsCompleted = milestones.allSatisfy(\.isCompleted)
        if timelineIsCompleted != isCompleted {
            completedDate = timelineIsCompleted ? Date() : nil
        }
        isCompleted = timelineIsCompleted
        stageName = milestones.first(where: { !$0.isCompleted })?.title ?? milestones.last?.title ?? type.defaultStage
        percentageProgress = Double(milestones.filter(\.isCompleted).count) / Double(milestones.count)
    }
}

nonisolated struct PlanoraCalendarDay: Codable, Hashable {
    let year: Int
    let month: Int
    let day: Int

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        year = components.year ?? 1970
        month = components.month ?? 1
        day = components.day ?? 1
    }

    init?(identifier: String) {
        let parts = identifier.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              (1...12).contains(parts[1]),
              (1...31).contains(parts[2]) else { return nil }
        year = parts[0]
        month = parts[1]
        day = parts[2]
    }

    var identifier: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    func date(calendar: Calendar = .current) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

// MARK: - Academic Timeline

struct AcademicMilestone: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var targetDate: Date?
    var isCompleted = false

    var localizedTitle: String {
        title.planoraLocalizedStageName
    }

    static func defaults(for type: TaskType, createdDate: Date, deadline: Date?) -> [AcademicMilestone] {
        let stages = type.stageOptions
        guard !stages.isEmpty else { return [] }

        return stages.enumerated().map { index, stage in
            AcademicMilestone(
                title: stage,
                targetDate: targetDate(
                    at: index,
                    stageCount: stages.count,
                    createdDate: createdDate,
                    deadline: deadline
                )
            )
        }
    }

    static func encodedDefaults(for type: TaskType, createdDate: Date, deadline: Date?) -> Data? {
        try? JSONEncoder().encode(defaults(for: type, createdDate: createdDate, deadline: deadline))
    }

    private static func targetDate(at index: Int, stageCount: Int, createdDate: Date, deadline: Date?) -> Date? {
        guard let deadline, stageCount > 0 else { return nil }
        let start = min(createdDate, deadline)
        let duration = deadline.timeIntervalSince(start)
        let fraction = Double(index + 1) / Double(stageCount)
        return start.addingTimeInterval(duration * fraction)
    }
}

// MARK: - Task Priority

enum TaskPriority: Int, Codable, CaseIterable, Identifiable, Hashable {
    case low = 0
    case medium = 1
    case high = 2

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .low: String(localized: "Low")
        case .medium: String(localized: "Medium")
        case .high: String(localized: "High")
        }
    }

    var symbol: String {
        switch self {
        case .low: "arrow.down"
        case .medium: "minus"
        case .high: "exclamationmark"
        }
    }

    var tint: Color {
        switch self {
        case .low: .gray
        case .medium: .planoraBlue
        case .high: .red
        }
    }
}

// MARK: - Task Type

enum TaskType: String, Codable, CaseIterable, Identifiable, Hashable {
    case assignment
    case practical
    case revision
    case ia
    case ee
    case tok
    case cas
    case exam
    case event
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .assignment: String(localized: "Assignment")
        case .practical: String(localized: "Practical")
        case .revision: String(localized: "Revision")
        case .ia: "IA"
        case .ee: "EE"
        case .tok: "TOK"
        case .cas: "CAS"
        case .exam: String(localized: "Exam")
        case .event: String(localized: "Event")
        case .custom: String(localized: "Custom")
        }
    }

    var symbol: String {
        switch self {
        case .assignment: "doc.richtext.fill"
        case .practical: "testtube.2"
        case .revision: "books.vertical.fill"
        case .ia: "flask.fill"
        case .ee: "book.pages.fill"
        case .tok: "lightbulb.max.fill"
        case .cas: "heart.text.square.fill"
        case .exam: "checkmark.seal.fill"
        case .event: "calendar"
        case .custom: "square.and.pencil"
        }
    }

    var tint: Color {
        switch self {
        case .assignment: .planoraBlue
        case .practical: .planoraGreen
        case .revision: .planoraAmber
        case .ia: .planoraBlue
        case .ee: .planoraGreen
        case .tok: .planoraAmber
        case .cas: .pink
        case .exam: .purple
        case .event: .teal
        case .custom: .planoraInk
        }
    }

    static func availableTypes(for curriculum: Curriculum, selectedSubjects: [String]) -> [TaskType] {
        let selectedSubjectSet = Set(selectedSubjects)
        let academicSubjects = selectedSubjects.filter {
            !SubjectLibrary.isCoreSubject($0, for: curriculum)
        }

        switch curriculum {
        case .ib:
            var types: [TaskType] = []

            if !academicSubjects.isEmpty {
                types.append(contentsOf: [.assignment, .ia, .exam])
            }

            // IB core workflows appear only when the matching core item is selected.
            if selectedSubjectSet.contains("EE") {
                types.append(.ee)
            }

            if selectedSubjectSet.contains("TOK") {
                types.append(.tok)
            }

            if selectedSubjectSet.contains("CAS") {
                types.append(.cas)
            }

            types.append(contentsOf: [.event, .custom])
            return types
        case .igcse:
            var types: [TaskType] = []

            if !selectedSubjects.isEmpty {
                types.append(contentsOf: [.assignment, .practical, .revision, .exam])
            }

            types.append(contentsOf: [.event, .custom])
            return types
        }
    }

    func subjectOptions(
        for curriculum: Curriculum,
        selectedSubjects: [String],
        selectedExtraLearning: [String]
    ) -> [String] {
        let selectedSubjectSet = Set(selectedSubjects)
        let academicSubjects = selectedSubjects.filter {
            !SubjectLibrary.isCoreSubject($0, for: curriculum)
        }

        switch self {
        case .assignment, .practical, .revision, .ia, .exam:
            return academicSubjects
        case .ee:
            return selectedSubjectSet.contains("EE") ? ["EE"] : []
        case .tok:
            return selectedSubjectSet.contains("TOK") ? ["TOK"] : []
        case .cas:
            return selectedSubjectSet.contains("CAS") ? ["CAS"] : []
        case .event, .custom:
            return (["通用"] + selectedSubjects + selectedExtraLearning).planoraOrderedUnique
        }
    }

    var defaultProgressState: ProgressState {
        switch self {
        case .practical, .revision, .ia, .ee, .tok, .cas:
            .stage(defaultStage)
        case .assignment, .exam, .event, .custom:
            .percentage(0)
        }
    }

    var tracksProgressByDefault: Bool {
        switch self {
        case .assignment, .practical, .revision, .ia, .ee, .tok, .cas:
            true
        case .exam, .event, .custom:
            false
        }
    }

    var usesDeadlineByDefault: Bool {
        switch self {
        case .assignment, .practical, .ia, .ee, .tok, .exam, .event:
            true
        case .revision, .cas, .custom:
            false
        }
    }

    var recommendedDeadlineOffset: Int {
        switch self {
        case .assignment:
            7
        case .practical:
            14
        case .revision:
            0
        case .ia, .tok:
            30
        case .ee:
            90
        case .exam:
            21
        case .event:
            14
        case .cas, .custom:
            0
        }
    }

    var allowsGeneralSubject: Bool {
        switch self {
        case .event, .custom, .cas, .revision:
            true
        case .assignment, .practical, .ia, .ee, .tok, .exam:
            false
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .assignment:
            String(localized: "Physics Assignment")
        case .practical:
            String(localized: "Physics Practical")
        case .revision:
            String(localized: "Math Revision")
        case .ia:
            "Physics IA"
        case .ee:
            "EE"
        case .tok:
            String(localized: "TOK Exhibition")
        case .cas:
            String(localized: "CAS Reflection")
        case .exam:
            String(localized: "Math Mock Exam")
        case .event:
            String(localized: "University Talk")
        case .custom:
            String(localized: "Read Chapter 5")
        }
    }

    func defaultTitle(for subject: String) -> String {
        guard !subject.isEmpty, subject != "通用", subject != "General" else {
            return titlePlaceholder
        }

        switch self {
        case .assignment:
            return PlanoraLocalization.format(String(localized: "default_assignment_title_format"), subject)
        case .practical:
            return PlanoraLocalization.format(String(localized: "default_practical_title_format"), subject)
        case .revision:
            return PlanoraLocalization.format(String(localized: "default_revision_title_format"), subject)
        case .ia:
            return "\(subject) IA"
        case .ee:
            return "EE"
        case .tok:
            return String(localized: "TOK Exhibition")
        case .cas:
            return String(localized: "CAS Reflection")
        case .exam:
            return PlanoraLocalization.format(String(localized: "default_exam_title_format"), subject)
        case .event:
            return titlePlaceholder
        case .custom:
            return titlePlaceholder
        }
    }

    var defaultStage: String {
        stageOptions.first ?? String(localized: "Not started")
    }

    var stageOptions: [String] {
        switch self {
        case .ia:
            [
                String(localized: "Research Question"),
                String(localized: "Methodology"),
                String(localized: "Data Collection"),
                String(localized: "Analysis"),
                String(localized: "Evaluation"),
                String(localized: "Final Submission")
            ]
        case .ee:
            [
                String(localized: "Topic"),
                String(localized: "Research Question"),
                String(localized: "Outline"),
                String(localized: "Draft"),
                String(localized: "Supervisor Feedback"),
                String(localized: "Final Reflection")
            ]
        case .tok:
            [
                String(localized: "Prompt"),
                String(localized: "Objects"),
                String(localized: "Commentary"),
                String(localized: "Final Submission")
            ]
        case .cas:
            [
                String(localized: "Plan"),
                String(localized: "Experience"),
                String(localized: "Evidence"),
                String(localized: "Reflection"),
                String(localized: "Complete")
            ]
        case .assignment:
            [
                String(localized: "Not started"),
                String(localized: "In progress"),
                String(localized: "Review"),
                String(localized: "Submitted")
            ]
        case .practical:
            [
                String(localized: "Plan"),
                String(localized: "Preparation"),
                String(localized: "Practical"),
                String(localized: "Results"),
                String(localized: "Evaluation")
            ]
        case .revision:
            [
                String(localized: "Plan"),
                String(localized: "Content Review"),
                String(localized: "Past Papers"),
                String(localized: "Weak Areas"),
                String(localized: "Ready")
            ]
        case .exam:
            [
                String(localized: "Planning"),
                String(localized: "Revision"),
                String(localized: "Practice"),
                String(localized: "Ready")
            ]
        case .event:
            [
                String(localized: "Planned"),
                String(localized: "Prepared"),
                String(localized: "Complete")
            ]
        case .custom:
            [
                String(localized: "Not started"),
                String(localized: "In progress"),
                String(localized: "Review"),
                String(localized: "Complete")
            ]
        }
    }
}

// MARK: - Progress Model

enum ProgressKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case percentage
    case stage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentage: String(localized: "Percentage")
        case .stage: String(localized: "Stage")
        }
    }
}

enum ProgressState: Codable, Hashable {
    case percentage(Double)
    case stage(String)

    var kind: ProgressKind {
        switch self {
        case .percentage: .percentage
        case .stage: .stage
        }
    }

    var label: String {
        switch self {
        case .percentage:
            String(localized: "Progress")
        case .stage:
            String(localized: "Stage")
        }
    }

    var valueText: String {
        switch self {
        case .percentage(let value):
            PlanoraFormat.percent(value)
        case .stage(let stage):
            stage.planoraLocalizedStageName
        }
    }

    var percentageValue: Double? {
        switch self {
        case .percentage(let value):
            min(max(value, 0), 1)
        case .stage:
            nil
        }
    }

    var stageValue: String? {
        switch self {
        case .percentage:
            nil
        case .stage(let stage):
            stage
        }
    }
}

// MARK: - Local Helpers

private extension String {
    var planoraLocalizedStageName: String {
        switch self {
        case "Research Question", "研究问题": String(localized: "Research Question")
        case "Method", "方法": String(localized: "Method")
        case "Methodology", "方法设计": String(localized: "Methodology")
        case "Data Collection", "数据收集": String(localized: "Data Collection")
        case "Analysis", "分析": String(localized: "Analysis")
        case "Evaluation", "评估": String(localized: "Evaluation")
        case "Final Submission", "最终提交": String(localized: "Final Submission")
        case "Final", "最终版": String(localized: "Final")
        case "Topic", "选题": String(localized: "Topic")
        case "Research", "研究": String(localized: "Research")
        case "Outline", "大纲": String(localized: "Outline")
        case "Draft", "草稿": String(localized: "Draft")
        case "Reflection", "反思": String(localized: "Reflection")
        case "Supervisor Feedback", "导师反馈": String(localized: "Supervisor Feedback")
        case "Final Reflection", "最终反思": String(localized: "Final Reflection")
        case "Prompt", "题目": String(localized: "Prompt")
        case "Objects", "对象": String(localized: "Objects")
        case "Commentary", "评述": String(localized: "Commentary")
        case "Submission", "提交": String(localized: "Submission")
        case "Plan", "计划": String(localized: "Plan")
        case "Experience", "体验": String(localized: "Experience")
        case "Evidence", "证据": String(localized: "Evidence")
        case "Complete", "完成": String(localized: "Complete")
        case "Not started", "未开始": String(localized: "Not started")
        case "In progress", "进行中": String(localized: "In progress")
        case "Review", "检查": String(localized: "Review")
        case "Submitted", "已提交": String(localized: "Submitted")
        case "Planning": String(localized: "Planning")
        case "Revision", "复习": String(localized: "Revision")
        case "Practice", "练习": String(localized: "Practice")
        case "Ready", "准备好": String(localized: "Ready")
        case "Planned", "已计划": String(localized: "Planned")
        case "Prepared", "已准备": String(localized: "Prepared")
        case "Brief", "任务要求": String(localized: "Brief")
        case "Feedback", "反馈": String(localized: "Feedback")
        case "Preparation", "准备": String(localized: "Preparation")
        case "Practical", "实验实践": String(localized: "Practical")
        case "Results", "结果": String(localized: "Results")
        case "Content Review", "知识复习": String(localized: "Content Review")
        case "Past Papers", "历年真题": String(localized: "Past Papers")
        case "Weak Areas", "薄弱环节": String(localized: "Weak Areas")
        default: self
        }
    }
}

private extension Array where Element == String {
    var planoraOrderedUnique: [String] {
        var seen = Set<String>()
        return filter { item in
            seen.insert(item).inserted
        }
    }
}
