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
            ? L("未设置", "Not Set")
            : LF("reminder_count_format", reminders.count)
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
        recurrenceRule?.summary ?? L("不重复", "Does Not Repeat")
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

    func normalizeCalendarDates(calendar: Calendar = .current) {
        if hasDeadline, let deadline {
            let day = deadlineDayIdentifier.flatMap { PlanoraCalendarDay(identifier: $0) }
                ?? PlanoraCalendarDay(date: deadline, calendar: calendar)
            deadlineDayIdentifier = day.identifier
            self.deadline = day.date(calendar: calendar)
        } else {
            deadline = nil
            deadlineDayIdentifier = nil
        }

        if let plannedDate {
            let day = plannedDayIdentifier.flatMap { PlanoraCalendarDay(identifier: $0) }
                ?? PlanoraCalendarDay(date: plannedDate, calendar: calendar)
            plannedDayIdentifier = day.identifier
            self.plannedDate = day.date(calendar: calendar)
        } else {
            plannedDayIdentifier = nil
        }
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
        case .low: L("低", "Low")
        case .medium: L("中", "Medium")
        case .high: L("高", "High")
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
        case .assignment: L("作业", "Assignment")
        case .practical: L("实验实践", "Practical")
        case .revision: L("复习计划", "Revision")
        case .ia: "IA"
        case .ee: "EE"
        case .tok: "TOK"
        case .cas: "CAS"
        case .exam: L("考试", "Exam")
        case .event: L("事件", "Event")
        case .custom: L("自定义", "Custom")
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
            L("Physics 作业", "Physics Assignment")
        case .practical:
            L("Physics 实验", "Physics Practical")
        case .revision:
            L("Math 复习", "Math Revision")
        case .ia:
            "Physics IA"
        case .ee:
            "EE"
        case .tok:
            L("TOK 展览", "TOK Exhibition")
        case .cas:
            L("CAS 反思", "CAS Reflection")
        case .exam:
            L("Math 模拟考试", "Math Mock Exam")
        case .event:
            L("大学讲座", "University Talk")
        case .custom:
            L("阅读第 5 章", "Read Chapter 5")
        }
    }

    func defaultTitle(for subject: String) -> String {
        guard !subject.isEmpty, subject != "通用", subject != "General" else {
            return titlePlaceholder
        }

        switch self {
        case .assignment:
            return LF("default_assignment_title_format", subject)
        case .practical:
            return LF("default_practical_title_format", subject)
        case .revision:
            return LF("default_revision_title_format", subject)
        case .ia:
            return "\(subject) IA"
        case .ee:
            return "EE"
        case .tok:
            return L("TOK 展览", "TOK Exhibition")
        case .cas:
            return L("CAS 反思", "CAS Reflection")
        case .exam:
            return LF("default_exam_title_format", subject)
        case .event:
            return titlePlaceholder
        case .custom:
            return titlePlaceholder
        }
    }

    var defaultStage: String {
        stageOptions.first ?? L("未开始", "Not started")
    }

    var stageOptions: [String] {
        switch self {
        case .ia:
            [
                L("研究问题", "Research Question"),
                L("方法设计", "Methodology"),
                L("数据收集", "Data Collection"),
                L("分析", "Analysis"),
                L("评估", "Evaluation"),
                L("最终提交", "Final Submission")
            ]
        case .ee:
            [
                L("选题", "Topic"),
                L("研究问题", "Research Question"),
                L("大纲", "Outline"),
                L("草稿", "Draft"),
                L("导师反馈", "Supervisor Feedback"),
                L("最终反思", "Final Reflection")
            ]
        case .tok:
            [
                L("题目", "Prompt"),
                L("对象", "Objects"),
                L("评述", "Commentary"),
                L("最终提交", "Final Submission")
            ]
        case .cas:
            [
                L("计划", "Plan"),
                L("体验", "Experience"),
                L("证据", "Evidence"),
                L("反思", "Reflection"),
                L("完成", "Complete")
            ]
        case .assignment:
            [
                L("未开始", "Not started"),
                L("进行中", "In progress"),
                L("检查", "Review"),
                L("已提交", "Submitted")
            ]
        case .practical:
            [
                L("计划", "Plan"),
                L("准备", "Preparation"),
                L("实验实践", "Practical"),
                L("结果", "Results"),
                L("评估", "Evaluation")
            ]
        case .revision:
            [
                L("制定计划", "Plan"),
                L("知识复习", "Content Review"),
                L("历年真题", "Past Papers"),
                L("薄弱环节", "Weak Areas"),
                L("准备好", "Ready")
            ]
        case .exam:
            [
                L("计划", "Planning"),
                L("复习", "Revision"),
                L("练习", "Practice"),
                L("准备好", "Ready")
            ]
        case .event:
            [
                L("已计划", "Planned"),
                L("已准备", "Prepared"),
                L("完成", "Complete")
            ]
        case .custom:
            [
                L("未开始", "Not started"),
                L("进行中", "In progress"),
                L("检查", "Review"),
                L("完成", "Complete")
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
        case .percentage: L("百分比", "Percentage")
        case .stage: L("阶段", "Stage")
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
            L("进度", "Progress")
        case .stage:
            L("阶段", "Stage")
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
        case "Research Question", "研究问题": L("研究问题", "Research Question")
        case "Method", "方法": L("方法", "Method")
        case "Methodology", "方法设计": L("方法设计", "Methodology")
        case "Data Collection", "数据收集": L("数据收集", "Data Collection")
        case "Analysis", "分析": L("分析", "Analysis")
        case "Evaluation", "评估": L("评估", "Evaluation")
        case "Final Submission", "最终提交": L("最终提交", "Final Submission")
        case "Final", "最终版": L("最终版", "Final")
        case "Topic", "选题": L("选题", "Topic")
        case "Research", "研究": L("研究", "Research")
        case "Outline", "大纲": L("大纲", "Outline")
        case "Draft", "草稿": L("草稿", "Draft")
        case "Reflection", "反思": L("反思", "Reflection")
        case "Supervisor Feedback", "导师反馈": L("导师反馈", "Supervisor Feedback")
        case "Final Reflection", "最终反思": L("最终反思", "Final Reflection")
        case "Prompt", "题目": L("题目", "Prompt")
        case "Objects", "对象": L("对象", "Objects")
        case "Commentary", "评述": L("评述", "Commentary")
        case "Submission", "提交": L("提交", "Submission")
        case "Plan", "计划": L("计划", "Plan")
        case "Experience", "体验": L("体验", "Experience")
        case "Evidence", "证据": L("证据", "Evidence")
        case "Complete", "完成": L("完成", "Complete")
        case "Not started", "未开始": L("未开始", "Not started")
        case "In progress", "进行中": L("进行中", "In progress")
        case "Review", "检查": L("检查", "Review")
        case "Submitted", "已提交": L("已提交", "Submitted")
        case "Planning": L("计划", "Planning")
        case "Revision", "复习": L("复习", "Revision")
        case "Practice", "练习": L("练习", "Practice")
        case "Ready", "准备好": L("准备好", "Ready")
        case "Planned", "已计划": L("已计划", "Planned")
        case "Prepared", "已准备": L("已准备", "Prepared")
        case "Brief", "任务要求": L("任务要求", "Brief")
        case "Feedback", "反馈": L("反馈", "Feedback")
        case "Preparation", "准备": L("准备", "Preparation")
        case "Practical", "实验实践": L("实验实践", "Practical")
        case "Results", "结果": L("结果", "Results")
        case "Content Review", "知识复习": L("知识复习", "Content Review")
        case "Past Papers", "历年真题": L("历年真题", "Past Papers")
        case "Weak Areas", "薄弱环节": L("薄弱环节", "Weak Areas")
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
