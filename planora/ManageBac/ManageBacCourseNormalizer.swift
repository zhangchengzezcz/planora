import Foundation

enum ManageBacProgrammeDetector {
    static func detect(programmeText: String?, courses: [ManageBacCourseRecord]) -> ManageBacProgrammeDetection {
        let source = ([programmeText] + courses.map(\.name) + courses.compactMap(\.programmeText))
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        var ibEvidence: [String] = []
        var igcseEvidence: [String] = []

        if source.range(of: #"\bib\s*(diploma|dp)\b|\bdp\s*[12]?\b"#, options: .regularExpression) != nil {
            ibEvidence.append("IB Diploma / DP")
        }
        if source.range(of: #"\b(hl|sl)\b"#, options: .regularExpression) != nil {
            ibEvidence.append("HL / SL")
        }
        if ["theory of knowledge", "tok", "extended essay", "cas"].contains(where: source.contains) {
            ibEvidence.append("IB core")
        }
        if source.range(of: #"\bigcse\b|\binternational\s+gcse\b"#, options: .regularExpression) != nil {
            igcseEvidence.append("IGCSE")
        }
        if source.range(of: #"\bpdp\b"#, options: .regularExpression) != nil {
            igcseEvidence.append("PDP")
        }

        if !ibEvidence.isEmpty, !igcseEvidence.isEmpty {
            return ManageBacProgrammeDetection(curriculum: nil, confidence: .conflicting, evidence: ibEvidence + igcseEvidence)
        }
        if !ibEvidence.isEmpty {
            return ManageBacProgrammeDetection(curriculum: .ib, confidence: .high, evidence: ibEvidence)
        }
        if igcseEvidence.contains("IGCSE") {
            return ManageBacProgrammeDetection(curriculum: .igcse, confidence: .high, evidence: igcseEvidence)
        }
        if igcseEvidence.contains("PDP") {
            return ManageBacProgrammeDetection(curriculum: .igcse, confidence: .medium, evidence: igcseEvidence)
        }
        return ManageBacProgrammeDetection(curriculum: nil, confidence: .low, evidence: [])
    }
}

struct ManageBacNormalizedCourse: Equatable, Sendable {
    var canonicalSubject: String
    var displayName: String
    var level: CourseLevel?
    var curriculum: Curriculum
    var requiresReview: Bool
}

enum ManageBacCourseNormalizer {
    static func normalize(_ record: ManageBacCourseRecord, curriculum: Curriculum) -> ManageBacNormalizedCourse {
        let source = normalized(record.name)
        let level: CourseLevel?
        if source.range(of: #"\bhl\b"#, options: .regularExpression) != nil {
            level = .hl
        } else if source.range(of: #"\bsl\b"#, options: .regularExpression) != nil {
            level = .sl
        } else {
            level = nil
        }

        let aliases: [(String, [String])] = [
            ("Mathematics", ["mathematics", "maths", "math"]),
            ("Physics", ["physics"]),
            ("Chemistry", ["chemistry"]),
            ("Biology", ["biology"]),
            ("Computer Science", ["computer science", "computing"]),
            ("Economics", ["economics"]),
            ("Business", ["business management", "business studies", "business"]),
            ("Geography", ["geography"]),
            ("History", ["history"]),
            ("English", ["english"]),
            ("Chinese", ["chinese", "mandarin"]),
            ("TOK", ["theory of knowledge", "tok"]),
            ("EE", ["extended essay"]),
            ("CAS", ["creativity activity service", "cas"])
        ]

        let canonical = aliases.first { _, values in values.contains(where: source.contains) }?.0
        let base = canonical ?? record.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let display = level.map { "\(base) \($0.title)" } ?? base
        return ManageBacNormalizedCourse(
            canonicalSubject: base,
            displayName: display,
            level: level,
            curriculum: curriculum,
            requiresReview: canonical == nil
        )
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
            .lowercased()
    }
}
