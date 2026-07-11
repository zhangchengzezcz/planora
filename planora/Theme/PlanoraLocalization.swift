import Foundation

enum PlanoraLocalization {
    static var preferredLocale: Locale {
        let identifier = Bundle.main.preferredLocalizations.first ?? "en"
        return Locale(identifier: identifier)
    }

    static var usesChineseLocalization: Bool {
        preferredLocale.identifier.lowercased().hasPrefix("zh")
    }

    static func string(_ key: String) -> String {
        String(localized: String.LocalizationValue(key))
    }

    static func format(_ key: String, _ arguments: [CVarArg]) -> String {
        let format = NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
        return String(format: format, locale: preferredLocale, arguments: arguments)
    }
}

func L(_ chinese: String, _ english: String) -> String {
    PlanoraLocalization.string(english)
}

func LF(_ key: String, _ arguments: CVarArg...) -> String {
    PlanoraLocalization.format(key, arguments)
}

enum PlanoraFormat {
    static func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    static func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMM")
        return formatter.string(from: date)
    }

    static func monthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date)
    }

    static func percent(_ value: Double) -> String {
        let clampedValue = min(max(value, 0), 1)
        let formatter = NumberFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: clampedValue)) ?? "\(Int(clampedValue * 100))%"
    }

    static var weekdays: [String] {
        let formatter = DateFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        guard symbols.count == 7 else { return symbols }
        return Array(symbols[1...6]) + [symbols[0]]
    }

    static func subjectDisplayName(_ subject: String) -> String {
        switch subject {
        case "General", "通用":
            PlanoraLocalization.string("General")
        case "补习":
            PlanoraLocalization.string("Tutoring")
        case "竞赛":
            PlanoraLocalization.string("Competitions")
        case "语言学习":
            PlanoraLocalization.string("Language Study")
        case "其他":
            PlanoraLocalization.string("Other")
        case "其他科目":
            PlanoraLocalization.string("Other Subject")
        default:
            subject
        }
    }
}
