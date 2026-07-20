import Foundation

enum PlanoraLocalization {
    static var preferredLocale: Locale {
        let identifier = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: identifier)
    }

    static func format(_ format: String, _ arguments: CVarArg...) -> String {
        return String(format: format, locale: preferredLocale, arguments: arguments)
    }
}

enum PlanoraFormat {
    private static let monthDayFormatter = dateFormatter(template: "MMM d")
    private static let monthTitleFormatter = dateFormatter(template: "MMMM")
    private static let monthYearFormatter = dateFormatter(template: "MMMM yyyy")
    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()
    private static let localizedWeekdays: [String] = {
        var calendar = Calendar.current
        calendar.locale = PlanoraLocalization.preferredLocale
        let symbols = calendar.veryShortWeekdaySymbols
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...6]) + [symbols[0]]
    }()

    static func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        monthTitleFormatter.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        monthYearFormatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        return percentFormatter.string(from: NSNumber(value: clampedValue)) ?? "\(Int(clampedValue * 100))%"
    }

    static var weekdays: [String] {
        localizedWeekdays
    }

    private static func dateFormatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }

    static func subjectDisplayName(_ subject: String) -> String {
        switch subject {
        case "General", "通用":
            String(localized: "General")
        case "补习":
            String(localized: "Tutoring")
        case "竞赛":
            String(localized: "Competitions")
        case "语言学习":
            String(localized: "Language Study")
        case "其他":
            String(localized: "Other")
        case "其他科目":
            String(localized: "Other Subject")
        default:
            subject
        }
    }
}
