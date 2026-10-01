import SwiftUI

enum OnboardingBrand {
    static func background(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.075, green: 0.085, blue: 0.095)
            : Color(red: 0.955, green: 0.968, blue: 0.975)
    }

    static func accent(for scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.49, green: 0.77, blue: 0.80)
            : Color(red: 0.20, green: 0.48, blue: 0.55)
    }
}

struct OnboardingCopy {
    let locale: Locale

    private func text(_ english: String, _ chinese: String, _ japanese: String) -> String {
        switch locale.language.languageCode?.identifier {
        case "zh": chinese
        case "ja": japanese
        default: english
        }
    }

    var subtitle: String { text("Your learning, brought together.", "把学习，清晰地放在一起。", "学びを、ひとつの場所に。") }
    var introduction: String { text("Tasks, courses and progress. One clear place to plan your next step.", "任务、课程与学习进度。清晰安排下一步。", "タスク、コース、学習の進捗。次の一歩をわかりやすく。") }
    var tasksTitle: String { text("Make room for what matters", "把重点放在眼前", "大切なことを、目の前に") }
    var tasksDetail: String { text("Deadlines, daily plans and task progress, together.", "截止日期、每天的计划与任务进度，一起掌握。", "期限、日々の予定、タスクの進捗をまとめて確認。") }
    var coursesTitle: String { text("See your learning clearly", "看清每一门课程", "コースごとの学びを確認") }
    var coursesDetail: String { text("Courses, grades and your latest timetable.", "课程、成绩与最新时间表，随时查看。", "コース、成績、最新の時間割をいつでも確認。") }
    var attendanceTitle: String { text("Stay connected to your week", "了解这一周的状态", "今週の状況を把握") }
    var attendanceDetail: String { text("Recent attendance and course messages in one place.", "最近七天出勤与课程消息，不错过重要更新。", "最近7日間の出席とコースのメッセージをひとつに。") }
}
