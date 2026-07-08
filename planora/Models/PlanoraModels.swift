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
    case create
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
        case .ib: "IB Diploma Programme"
        case .igcse: "IGCSE International GCSE"
        }
    }

    var subtitle: String {
        switch self {
        case .ib: "HL / SL / TOK / EE / CAS"
        case .igcse: "Core subjects and exam preparation"
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
            title: "选择适合你的课程体系",
            description: "支持 IB 与 IGCSE，从课程结构开始建立你的学习空间。",
            symbol: "sparkles.rectangle.stack.fill",
            tint: .planoraBlue
        ),
        PlanoraFeature(
            id: "milestones",
            title: "整理科目与额外学习",
            description: "把正在学习的科目、语言和竞赛内容放在同一个地方。",
            symbol: "book.pages.fill",
            tint: .planoraAmber
        ),
        PlanoraFeature(
            id: "progress",
            title: "关注任务、进度和日期",
            description: "主页会显示接下来的重点、完成进度和日历预览。",
            symbol: "chart.line.uptrend.xyaxis",
            tint: .planoraGreen
        )
    ]
}

struct DashboardTask: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let detail: String
    let progressText: String
    let progress: Double
    let tint: Color
}

struct ProgressSnapshot: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let value: Double
    let tint: Color
}

struct CalendarEvent: Identifiable, Hashable {
    let id = UUID()
    let day: Int
    let title: String
    let tint: Color
}
