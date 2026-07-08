import SwiftData
import SwiftUI

@Model
final class PlanoraTask {
    @Attribute(.unique) var id: UUID
    var title: String
    var subject: String
    var typeRawValue: String
    var deadline: Date?
    var hasDeadline: Bool
    var progressKindRawValue: String
    var percentageProgress: Double
    var stageName: String
    var notes: String
    var createdDate: Date
    var isCompleted: Bool
    var importance: Int

    init(
        id: UUID = UUID(),
        title: String,
        subject: String,
        type: TaskType,
        deadline: Date?,
        hasDeadline: Bool,
        progressState: ProgressState,
        notes: String,
        createdDate: Date = Date(),
        isCompleted: Bool = false,
        importance: Int = 0
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.typeRawValue = type.rawValue
        self.deadline = hasDeadline ? deadline : nil
        self.hasDeadline = hasDeadline
        self.progressKindRawValue = progressState.kind.rawValue
        self.percentageProgress = progressState.percentageValue ?? 0
        self.stageName = progressState.stageValue ?? type.defaultStage
        self.notes = notes
        self.createdDate = createdDate
        self.isCompleted = isCompleted
        self.importance = importance
    }

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
}

enum TaskType: String, Codable, CaseIterable, Identifiable, Hashable {
    case assignment
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
        case .assignment: "Assignment"
        case .ia: "IA"
        case .ee: "EE"
        case .tok: "TOK"
        case .cas: "CAS"
        case .exam: "Exam"
        case .event: "Event"
        case .custom: "Custom"
        }
    }

    var symbol: String {
        switch self {
        case .assignment: "doc.text.fill"
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
        case .ia: .planoraBlue
        case .ee: .planoraGreen
        case .tok: .planoraAmber
        case .cas: .pink
        case .exam: .purple
        case .event: .teal
        case .custom: .planoraInk
        }
    }

    var defaultProgressState: ProgressState {
        switch self {
        case .ia, .ee, .tok, .cas:
            .stage(defaultStage)
        case .assignment, .exam, .event, .custom:
            .percentage(0)
        }
    }

    var usesDeadlineByDefault: Bool {
        switch self {
        case .assignment, .ia, .ee, .tok, .exam, .event:
            true
        case .cas, .custom:
            false
        }
    }

    var recommendedDeadlineOffset: Int {
        switch self {
        case .assignment:
            7
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
        case .event, .custom, .cas:
            true
        case .assignment, .ia, .ee, .tok, .exam:
            false
        }
    }

    var titlePlaceholder: String {
        switch self {
        case .assignment:
            "Physics homework"
        case .ia:
            "Physics IA"
        case .ee:
            "Extended Essay"
        case .tok:
            "TOK Exhibition"
        case .cas:
            "CAS reflection"
        case .exam:
            "Math mock exam"
        case .event:
            "University webinar"
        case .custom:
            "Read chapter 5"
        }
    }

    func defaultTitle(for subject: String) -> String {
        guard !subject.isEmpty, subject != "General" else {
            return titlePlaceholder
        }

        switch self {
        case .assignment:
            return "\(subject) assignment"
        case .ia:
            return "\(subject) IA"
        case .ee:
            return "\(subject) EE"
        case .tok:
            return "TOK Exhibition"
        case .cas:
            return "CAS reflection"
        case .exam:
            return "\(subject) exam"
        case .event:
            return titlePlaceholder
        case .custom:
            return titlePlaceholder
        }
    }

    var defaultStage: String {
        stageOptions.first ?? "Not started"
    }

    var stageOptions: [String] {
        switch self {
        case .ia:
            ["Research Question", "Method", "Data Collection", "Analysis", "Final"]
        case .ee:
            ["Topic", "Research", "Outline", "Draft", "Reflection", "Final"]
        case .tok:
            ["Prompt", "Research", "Draft", "Submission"]
        case .cas:
            ["Plan", "Experience", "Evidence", "Reflection", "Complete"]
        case .assignment:
            ["Not started", "In progress", "Review", "Submitted"]
        case .exam:
            ["Planning", "Revision", "Practice", "Ready"]
        case .event:
            ["Planned", "Prepared", "Complete"]
        case .custom:
            ["Not started", "In progress", "Review", "Complete"]
        }
    }
}

enum ProgressKind: String, Codable, CaseIterable, Identifiable, Hashable {
    case percentage
    case stage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentage: "Percentage"
        case .stage: "Stage"
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
            "Progress"
        case .stage:
            "Stage"
        }
    }

    var valueText: String {
        switch self {
        case .percentage(let value):
            "\(Int(min(max(value, 0), 1) * 100))%"
        case .stage(let stage):
            stage
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
