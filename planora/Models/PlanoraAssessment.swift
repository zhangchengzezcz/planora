import Foundation
import SwiftData

@Model
final class PlanoraAssessment {
    @Attribute(.unique) var id: UUID
    var title: String
    var subject: String
    var earnedScore: Double
    var maximumScore: Double
    var date: Date
    var typeRawValue: String
    var notes: String
    var courseID: UUID?
    var createdDate: Date

    init(
        id: UUID = UUID(),
        title: String,
        subject: String,
        earnedScore: Double,
        maximumScore: Double,
        date: Date = Date(),
        type: AssessmentType = .quiz,
        notes: String = "",
        courseID: UUID? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subject = subject
        self.earnedScore = max(earnedScore, 0)
        self.maximumScore = max(maximumScore, 0.01)
        self.date = date
        self.typeRawValue = type.rawValue
        self.notes = notes
        self.courseID = courseID
        self.createdDate = createdDate
    }

    var type: AssessmentType {
        get { AssessmentType(rawValue: typeRawValue) ?? .quiz }
        set { typeRawValue = newValue.rawValue }
    }

    var percentage: Double {
        min(max(earnedScore / max(maximumScore, 0.01), 0), 1)
    }
}

enum AssessmentType: String, Codable, CaseIterable, Identifiable {
    case quiz
    case assignment
    case lab
    case mock
    case exam
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quiz: String(localized: "Quiz")
        case .assignment: String(localized: "Assignment")
        case .lab: String(localized: "Lab Report")
        case .mock: String(localized: "Mock Exam")
        case .exam: String(localized: "Exam")
        case .other: String(localized: "Other")
        }
    }
}
