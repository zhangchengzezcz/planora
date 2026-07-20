import SwiftUI

enum PlanoraPhase: Hashable {
    case welcome
    case features
    case name
    case curriculum
    case subjects
    case dashboard
}

enum MainTab: Hashable {
    case home
    case tasks
    case create
    case search
    case profile
}

enum Curriculum: String, CaseIterable, Codable, Identifiable, Hashable {
    case ib
    case igcse

    var id: String { rawValue }

    var badge: String {
        switch self {
        case .ib: "IB"
        case .igcse: "IGCSE"
        }
    }

    var title: String {
        switch self {
        case .ib: String(localized: "IB Diploma Programme")
        case .igcse: String(localized: "IGCSE International Curriculum")
        }
    }

    var subtitle: String {
        switch self {
        case .ib: "HL / SL / TOK / EE / CAS"
        case .igcse: String(localized: "Core subjects and exam preparation")
        }
    }

    var symbol: String {
        switch self {
        case .ib: "graduationcap.fill"
        case .igcse: "book.closed.fill"
        }
    }

    var tint: Color {
        switch self {
        case .ib: .planoraBlue
        case .igcse: .planoraGreen
        }
    }
}

struct LearningProfile: Codable, Equatable {
    var name: String
    var curriculum: Curriculum
    var subjects: [String]
    var extraLearning: [String]
    var completedTasks: Int
    var totalTasks: Int
}

struct SubjectOption: Identifiable, Hashable {
    let title: String
    var id: String { title }
}

struct PlanoraFeature: Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let symbol: String
    let tint: Color

    static let samples = [
        PlanoraFeature(
            id: "planning",
            title: String(localized: "Choose Your Curriculum"),
            description: String(localized: "Start with IB or IGCSE and build your learning space around your programme."),
            symbol: "sparkles.rectangle.stack.fill",
            tint: .planoraBlue
        ),
        PlanoraFeature(
            id: "milestones",
            title: String(localized: "Organize Subjects and Extras"),
            description: String(localized: "Keep subjects, language learning, competitions, and extras in one place."),
            symbol: "book.pages.fill",
            tint: .planoraAmber
        ),
        PlanoraFeature(
            id: "progress",
            title: String(localized: "Track Tasks, Progress, and Dates"),
            description: String(localized: "The home page highlights your next focus, progress, and important dates."),
            symbol: "chart.line.uptrend.xyaxis",
            tint: .planoraGreen
        )
    ]
}

struct SubjectProgressSnapshot: Identifiable, Hashable {
    let title: String
    let value: Double
    let tint: Color

    var id: String { title }
}

struct TaskCompletionSnapshot: Hashable {
    let title: String
    let completed: Int
    let total: Int
    let tint: Color

    var value: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    var valueText: String {
        PlanoraLocalization.format(String(localized: "task_completion_count_format"), completed, total)
    }
}

struct CalendarEvent: Identifiable, Hashable {
    let id = UUID()
    let day: Int
    let title: String
    let tint: Color
}
