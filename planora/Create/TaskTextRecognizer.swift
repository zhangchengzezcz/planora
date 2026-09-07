import Foundation

/// A deterministic, on-device parser for the iPhone quick-create field.
///
/// The recognizer deliberately limits itself to explicit evidence in the text.
/// It never invents a date or subject, and only returns subjects/types that are
/// valid in the caller's current learning space.
nonisolated struct TaskRecognitionResult: Equatable, Sendable {
    var title: String
    var subject: String?
    var type: TaskType?
    var deadline: Date?
    var priority: TaskPriority?

    var hasRecognizedMetadata: Bool {
        subject != nil || type != nil || deadline != nil || priority != nil
    }
}

nonisolated enum TaskTextRecognizer {
    static func recognize(
        _ text: String,
        subjects: [String],
        availableTypes: [TaskType],
        now: Date = Date(),
        calendar: Calendar = .current,
        locale: Locale = .current
    ) -> TaskRecognitionResult {
        let source = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else { return TaskRecognitionResult(title: "") }

        var consumedRanges: [Range<String.Index>] = []
        let subjectMatch = matchSubject(in: source, subjects: subjects, locale: locale)
        if let range = subjectMatch?.range { consumedRanges.append(range) }

        let typeMatch = matchType(in: source, availableTypes: availableTypes)
        if let range = typeMatch?.range { consumedRanges.append(range) }

        let dateMatch = matchDate(in: source, now: now, calendar: calendar, locale: locale)
        if let range = dateMatch?.range { consumedRanges.append(range) }

        let priorityMatch = matchPriority(in: source)
        if let range = priorityMatch?.range { consumedRanges.append(range) }

        return TaskRecognitionResult(
            title: cleanedTitle(from: source, removing: consumedRanges),
            subject: subjectMatch?.value,
            type: typeMatch?.value,
            deadline: dateMatch?.value,
            priority: priorityMatch?.value
        )
    }

    private static func matchSubject(
        in text: String,
        subjects: [String],
        locale: Locale
    ) -> (value: String, range: Range<String.Index>)? {
        let aliases: [(subject: String, alias: String)] = subjects.flatMap { subject in
            subjectAliases(for: subject, locale: locale).map { (subject, $0) }
        }
        .sorted { $0.alias.count > $1.alias.count }

        let matches = aliases.compactMap { candidate -> (subject: String, alias: String, range: Range<String.Index>)? in
            guard let range = tokenRange(of: candidate.alias, in: text) else { return nil }
            return (candidate.subject, candidate.alias, range)
        }
        guard let longestLength = matches.map(\.alias.count).max() else { return nil }
        let strongest = matches.filter { $0.alias.count == longestLength }
        let subjects = Set(strongest.map(\.subject))
        guard subjects.count == 1, let match = strongest.first else { return nil }
        return (match.subject, match.range)
    }

    private static func subjectAliases(for subject: String, locale: Locale) -> [String] {
        var aliases = [subject]
        let folded = subject.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: locale)

        let knownAliases: [(needle: String, values: [String])] = [
            ("mathematics", ["math", "maths", "数学", "數學", "数学科"]),
            ("physics", ["physics", "物理"]),
            ("chemistry", ["chemistry", "化学", "化學"]),
            ("biology", ["biology", "生物"]),
            ("computer science", ["computer science", "cs", "计算机", "計算機", "コンピュータサイエンス"]),
            ("economics", ["economics", "econ", "经济", "經濟", "経済"]),
            ("history", ["history", "历史", "歷史", "歴史"]),
            ("geography", ["geography", "geo", "地理"]),
            ("english", ["english", "英语", "英語"]),
            ("chinese", ["chinese", "中文", "语文", "中国語"]),
            ("business", ["business", "商科", "商业", "商業"]),
            ("psychology", ["psychology", "心理学", "心理學"]),
            ("visual arts", ["visual arts", "art", "美术", "美術"])
        ]

        for entry in knownAliases where folded.contains(entry.needle) {
            aliases.append(contentsOf: entry.values)
        }

        return Array(Set(aliases)).sorted { $0.count > $1.count }
    }

    private static func matchType(
        in text: String,
        availableTypes: [TaskType]
    ) -> (value: TaskType, range: Range<String.Index>)? {
        let keywords: [(TaskType, [String])] = [
            (.practical, ["practical", "lab report", "experiment", "实验", "實驗", "实验报告", "実験"]),
            (.revision, ["revision", "revise", "review", "复习", "複習", "復習"]),
            (.exam, ["mock exam", "exam", "test", "quiz", "考试", "考試", "测验", "測驗", "試験", "テスト"]),
            (.assignment, ["assignment", "homework", "coursework", "作业", "作業", "功课", "宿題"]),
            (.event, ["event", "meeting", "lecture", "活动", "活動", "讲座", "講座", "会議"]),
            (.ia, ["IA"]),
            (.ee, ["EE", "extended essay"]),
            (.tok, ["TOK", "theory of knowledge"]),
            (.cas, ["CAS"])
        ]

        for (type, candidates) in keywords where availableTypes.contains(type) {
            for keyword in candidates.sorted(by: { $0.count > $1.count }) {
                if let range = tokenRange(of: keyword, in: text) {
                    return (type, range)
                }
            }
        }
        return nil
    }

    private static func matchPriority(in text: String) -> (value: TaskPriority, range: Range<String.Index>)? {
        let groups: [(TaskPriority, [String])] = [
            (.low, ["not urgent", "low priority", "低优先级", "低優先級", "不急"]),
            (.high, ["high priority", "urgent", "important", "高优先级", "高優先級", "紧急", "緊急", "重要", "至急"]),
        ]
        let candidates = groups.flatMap { priority, keywords in
            keywords.map { (priority, $0) }
        }
        for (priority, keyword) in candidates.sorted(by: { $0.1.count > $1.1.count }) {
            if let range = tokenRange(of: keyword, in: text) {
                return (priority, range)
            }
        }
        return nil
    }

    private static func matchDate(
        in text: String,
        now: Date,
        calendar: Calendar,
        locale: Locale
    ) -> (value: Date, range: Range<String.Index>)? {
        let relativeDays: [(String, Int)] = [
            ("day after tomorrow", 2), ("后天", 2), ("後天", 2), ("明後日", 2),
            ("tomorrow", 1), ("明天", 1), ("明日", 1),
            ("today", 0), ("今天", 0), ("今日", 0)
        ]
        for (keyword, offset) in relativeDays {
            if let range = tokenRange(of: keyword, in: text),
               let date = calendar.date(byAdding: .day, value: offset, to: calendar.startOfDay(for: now)) {
                return (date, range)
            }
        }

        let numericPatterns = [
            #"(?<!\d)(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})(?!\d)"#,
            #"(?<!\d)(\d{1,2})[-/.](\d{1,2})(?![-/.\d])"#,
            #"(?<!\d)(\d{1,2})月(\d{1,2})[日号號]?"#
        ]
        for (index, pattern) in numericPatterns.enumerated() {
            guard let match = firstMatch(pattern: pattern, in: text),
                  let range = Range(match.range, in: text) else { continue }
            let values = (1..<match.numberOfRanges).compactMap { capture -> Int? in
                guard let captureRange = Range(match.range(at: capture), in: text) else { return nil }
                return Int(text[captureRange])
            }
            let components: DateComponents
            if index == 0, values.count == 3 {
                components = DateComponents(year: values[0], month: values[1], day: values[2])
            } else if values.count == 2 {
                let currentYear = calendar.component(.year, from: now)
                var year = currentYear
                if let candidate = calendar.date(from: DateComponents(year: year, month: values[0], day: values[1])),
                   candidate < calendar.startOfDay(for: now) {
                    year += 1
                }
                components = DateComponents(year: year, month: values[0], day: values[1])
            } else {
                continue
            }
            if let date = calendar.date(from: components),
               calendar.dateComponents([.year, .month, .day], from: date) == components {
                return (date, range)
            }
        }

        let weekdaySymbols: [(String, Int)] = [
            ("next monday", 2), ("monday", 2), ("mon", 2), ("下星期一", 2), ("下周一", 2), ("星期一", 2), ("周一", 2), ("来週月曜日", 2), ("月曜日", 2),
            ("next tuesday", 3), ("tuesday", 3), ("tue", 3), ("下星期二", 3), ("下周二", 3), ("星期二", 3), ("周二", 3), ("来週火曜日", 3), ("火曜日", 3),
            ("next wednesday", 4), ("wednesday", 4), ("wed", 4), ("下星期三", 4), ("下周三", 4), ("星期三", 4), ("周三", 4), ("来週水曜日", 4), ("水曜日", 4),
            ("next thursday", 5), ("thursday", 5), ("thu", 5), ("下星期四", 5), ("下周四", 5), ("星期四", 5), ("周四", 5), ("来週木曜日", 5), ("木曜日", 5),
            ("next friday", 6), ("friday", 6), ("fri", 6), ("下星期五", 6), ("下周五", 6), ("星期五", 6), ("周五", 6), ("来週金曜日", 6), ("金曜日", 6),
            ("next saturday", 7), ("saturday", 7), ("sat", 7), ("下星期六", 7), ("下周六", 7), ("星期六", 7), ("周六", 7), ("来週土曜日", 7), ("土曜日", 7),
            ("next sunday", 1), ("sunday", 1), ("sun", 1), ("下星期日", 1), ("下周日", 1), ("下周天", 1), ("星期日", 1), ("周日", 1), ("周天", 1), ("来週日曜日", 1), ("日曜日", 1)
        ]
        for (keyword, weekday) in weekdaySymbols {
            guard let range = tokenRange(of: keyword, in: text) else { continue }
            let today = calendar.startOfDay(for: now)
            let currentWeekday = calendar.component(.weekday, from: today)
            let delta = (weekday - currentWeekday + 7) % 7
            if let date = calendar.date(byAdding: .day, value: delta == 0 ? 7 : delta, to: today) {
                return (date, range)
            }
        }

        _ = locale // Reserved for locale-specific date grammar extensions.
        return nil
    }

    private static func tokenRange(of token: String, in text: String) -> Range<String.Index>? {
        let escaped = NSRegularExpression.escapedPattern(for: token)
        let beginsWithWord = token.first?.isASCII == true && token.first?.isLetter == true
        let endsWithWord = token.last?.isASCII == true && token.last?.isLetter == true
        let pattern = "\(beginsWithWord ? #"(?<![A-Za-z0-9])"# : "")\(escaped)\(endsWithWord ? #"(?![A-Za-z0-9])"# : "")"
        guard let match = firstMatch(pattern: pattern, in: text) else { return nil }
        return Range(match.range, in: text)
    }

    private static func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
        try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            .firstMatch(in: text, range: NSRange(text.startIndex..., in: text))
    }

    private static func cleanedTitle(
        from text: String,
        removing ranges: [Range<String.Index>]
    ) -> String {
        var result = text
        for range in ranges.sorted(by: { $0.lowerBound > $1.lowerBound }) {
            guard let lower = range.lowerBound.samePosition(in: result),
                  let upper = range.upperBound.samePosition(in: result) else { continue }
            result.removeSubrange(lower..<upper)
        }

        result = result
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",，:：;；|@#-")))
        return result.isEmpty ? text : result
    }
}
