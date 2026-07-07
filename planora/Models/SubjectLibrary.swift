enum SubjectLibrary {
    static let ibSubjects = [
        "Mathematics AA HL",
        "Physics HL",
        "Chemistry SL",
        "English B SL",
        "Economics SL",
        "TOK",
        "EE",
        "CAS"
    ]

    static let igcseSubjects = [
        "Mathematics",
        "English",
        "Physics",
        "Chemistry",
        "Biology",
        "Computer Science",
        "Geography",
        "History"
    ]

    static let extraLearning = ["补习", "竞赛", "语言学习", "其他"]

    static let defaultIBSubjects = ["Physics HL", "Mathematics AA HL", "English B SL"]
    static let defaultIGCSESubjects = ["Mathematics", "English", "Physics"]

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
}
