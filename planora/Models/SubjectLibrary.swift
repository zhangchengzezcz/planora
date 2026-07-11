import Foundation

enum SubjectLibrary {
    // MARK: - Built-In Subjects

    // These lists cover common IB/IGCSE offerings. Schools vary, so the pickers
    // also allow custom subjects without mixing them into another curriculum.
    static let ibSubjects = [
        "Mathematics AA HL",
        "Mathematics AA SL",
        "Mathematics AI HL",
        "Mathematics AI SL",
        "English A: Language and Literature HL",
        "English A: Language and Literature SL",
        "English A: Literature HL",
        "English A: Literature SL",
        "Physics HL",
        "Physics SL",
        "Biology HL",
        "Biology SL",
        "Chemistry HL",
        "Chemistry SL",
        "Computer Science HL",
        "Computer Science SL",
        "Design Technology HL",
        "Design Technology SL",
        "Environmental Systems and Societies HL",
        "Environmental Systems and Societies SL",
        "Sports, Exercise and Health Science HL",
        "Sports, Exercise and Health Science SL",
        "Literature and Performance SL",
        "English B SL",
        "English B HL",
        "Chinese B HL",
        "Chinese B SL",
        "Chinese A: Language and Literature HL",
        "Chinese A: Language and Literature SL",
        "Chinese A: Literature HL",
        "Chinese A: Literature SL",
        "Chinese ab initio SL",
        "Spanish B HL",
        "Spanish B SL",
        "Spanish ab initio SL",
        "French B HL",
        "French B SL",
        "French ab initio SL",
        "German B HL",
        "German B SL",
        "Latin HL",
        "Latin SL",
        "Business Management HL",
        "Business Management SL",
        "Economics HL",
        "Economics SL",
        "Geography HL",
        "Geography SL",
        "Global Politics HL",
        "Global Politics SL",
        "History HL",
        "History SL",
        "Digital Society HL",
        "Digital Society SL",
        "Philosophy HL",
        "Philosophy SL",
        "Psychology HL",
        "Psychology SL",
        "Social and Cultural Anthropology HL",
        "Social and Cultural Anthropology SL",
        "World Religions SL",
        "Visual Arts HL",
        "Visual Arts SL",
        "Music HL",
        "Music SL",
        "Theatre HL",
        "Theatre SL",
        "Film HL",
        "Film SL",
        "Dance HL",
        "Dance SL",
        "TOK",
        "EE",
        "CAS"
    ]

    static let igcseSubjects = [
        "Mathematics",
        "English",
        "Additional Mathematics",
        "International Mathematics",
        "English First Language",
        "English Second Language",
        "English Literature",
        "English as an Additional Language",
        "Physics",
        "Chemistry",
        "Biology",
        "Combined Science",
        "Co-ordinated Sciences",
        "Physical Science",
        "Marine Science",
        "Environmental Management",
        "Computer Science",
        "Information and Communication Technology",
        "Accounting",
        "Business",
        "Business Studies",
        "Economics",
        "Enterprise",
        "Commerce",
        "Geography",
        "History",
        "Global Perspectives",
        "Sociology",
        "Psychology",
        "Religious Studies",
        "Islamiyat",
        "Pakistan Studies",
        "Art & Design",
        "Design & Technology",
        "Drama",
        "Music",
        "Physical Education",
        "Food & Nutrition",
        "Travel & Tourism",
        "Agriculture",
        "Statistics",
        "World Literature",
        "Arabic First Language",
        "Arabic Foreign Language",
        "Bahasa Indonesia",
        "Chinese First Language",
        "Chinese Second Language",
        "Chinese Foreign Language",
        "French First Language",
        "French Foreign Language",
        "German First Language",
        "German Foreign Language",
        "Hindi as a Second Language",
        "Italian Foreign Language",
        "Japanese Foreign Language",
        "Latin",
        "Malay First Language",
        "Malay Foreign Language",
        "Portuguese First Language",
        "Spanish First Language",
        "Spanish Foreign Language",
        "Spanish Literature",
        "Thai First Language",
        "Turkish First Language",
        "Urdu as a Second Language",
        "Vietnamese First Language"
    ]

    static let customSubjectTrigger = "其他科目"
    static let customExtraLearningTrigger = "其他"
    static let builtInExtraLearning = ["补习", "竞赛", "语言学习"]
    static let extraLearning = builtInExtraLearning + [customExtraLearningTrigger]

    // MARK: - Defaults and Required Items

    static let requiredIBSubjects = ["TOK", "EE", "CAS"]
    static let requiredIGCSESubjects = ["Mathematics", "English"]
    static let ibCoreSubjects = Set(requiredIBSubjects)

    static let defaultIBSubjects = ["Physics HL", "Mathematics AA HL", "English B SL"] + requiredIBSubjects
    static let defaultIGCSESubjects = requiredIGCSESubjects

    static var allKnownSubjects: Set<String> {
        Set(ibSubjects + igcseSubjects)
    }

    // MARK: - Lookup

    static func subjects(for curriculum: Curriculum) -> [SubjectOption] {
        switch curriculum {
        case .ib:
            ibSubjects.map(SubjectOption.init(title:))
        case .igcse:
            igcseSubjects.map(SubjectOption.init(title:))
        }
    }

    static func defaultSubjects(for curriculum: Curriculum) -> [String] {
        switch curriculum {
        case .ib:
            defaultIBSubjects
        case .igcse:
            defaultIGCSESubjects
        }
    }

    static func requiredSubjects(for curriculum: Curriculum) -> [String] {
        switch curriculum {
        case .ib:
            requiredIBSubjects
        case .igcse:
            requiredIGCSESubjects
        }
    }

    static func normalizedSubjects(for curriculum: Curriculum, subjects selectedSubjects: Set<String>) -> Set<String> {
        let validSubjects = Set(subjects(for: curriculum).map(\.title))
        // Preserve user-created subjects, but discard built-in subjects that belong
        // to a different curriculum. This keeps TOK/EE/CAS out of IGCSE after switches.
        let customSubjects = selectedSubjects.filter { subject in
            isCustomSubject(subject, for: curriculum)
        }
        var normalizedSubjects = selectedSubjects.intersection(validSubjects).union(customSubjects)

        if normalizedSubjects.isEmpty {
            normalizedSubjects = Set(defaultSubjects(for: curriculum))
        } else {
            normalizedSubjects.formUnion(requiredSubjects(for: curriculum))
        }

        return normalizedSubjects
    }

    static func isRequiredSubject(_ subject: String, for curriculum: Curriculum) -> Bool {
        requiredSubjects(for: curriculum).contains(subject)
    }

    static func isCustomSubject(_ subject: String, for curriculum: Curriculum) -> Bool {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty else { return false }
        guard trimmedSubject != customSubjectTrigger else { return false }
        // A custom subject is one the user typed, not an item from any built-in list.
        return !allKnownSubjects.contains(trimmedSubject)
    }

    static func isCoreSubject(_ subject: String, for curriculum: Curriculum) -> Bool {
        switch curriculum {
        case .ib:
            ibCoreSubjects.contains(subject)
        case .igcse:
            false
        }
    }
}
