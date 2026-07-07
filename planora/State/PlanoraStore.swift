import Foundation
import Observation

@MainActor
@Observable
final class PlanoraStore {
    var phase: PlanoraPhase = .welcome
    var curriculum: Curriculum = .ib
    var selectedSubjects: Set<String> = Set(SubjectLibrary.defaultIBSubjects)
    var selectedExtraLearning: Set<String> = ["语言学习"]
    var selectedTab: MainTab = .home
    var userName = ""

    @ObservationIgnored private let storage: PlanoraStorage

    convenience init() {
        self.init(storage: .live, loadSavedProfile: true)
    }

    init(storage: PlanoraStorage, loadSavedProfile: Bool) {
        self.storage = storage

        guard loadSavedProfile, let profile = storage.loadProfile() else {
            return
        }

        userName = profile.name
        curriculum = profile.curriculum
        selectedSubjects = Set(profile.subjects)
        selectedExtraLearning = Set(profile.extraLearning)
        phase = .dashboard
    }

    var selectedSubjectTitles: [String] {
        SubjectLibrary
            .subjects(for: curriculum)
            .map(\.title)
            .filter { selectedSubjects.contains($0) }
    }

    var selectedExtraLearningTitles: [String] {
        SubjectLibrary.extraLearning.filter { selectedExtraLearning.contains($0) }
    }

    var profile: LearningProfile {
        LearningProfile(
            name: userName,
            curriculum: curriculum,
            subjects: selectedSubjectTitles,
            extraLearning: selectedExtraLearningTitles,
            completedTasks: 12,
            totalTasks: 15
        )
    }

    var upcomingTasks: [DashboardTask] {
        [
            DashboardTask(
                title: curriculum == .ib ? "Physics IA" : "Physics Review",
                detail: "3 days left",
                progressText: "70% complete",
                progress: 0.7,
                tint: .planoraBlue
            ),
            DashboardTask(
                title: curriculum == .ib ? "TOK Exhibition" : "English Speaking",
                detail: "15 days left",
                progressText: "Outline ready",
                progress: 0.35,
                tint: .planoraAmber
            )
        ]
    }

    var progressSnapshots: [ProgressSnapshot] {
        let first = selectedSubjectTitles.first ?? "Physics HL"
        let second = selectedSubjectTitles.dropFirst().first ?? "Math AA HL"

        return [
            ProgressSnapshot(title: "\(first) progress", value: 0.72, tint: .planoraBlue),
            ProgressSnapshot(title: "\(second) progress", value: 0.58, tint: .planoraGreen)
        ]
    }

    var calendarEvents: [CalendarEvent] {
        [
            CalendarEvent(day: 7, title: "Physics IA", tint: .planoraBlue),
            CalendarEvent(day: 18, title: "TOK Exhibition", tint: .planoraAmber),
            CalendarEvent(day: 24, title: "Math Practice", tint: .planoraGreen)
        ]
    }

    func showFeatureIntro() {
        phase = .features
    }

    func showNameEntry() {
        phase = .name
    }

    func showCurriculumSelection() {
        phase = .curriculum
    }

    func updateUserName(_ newName: String) {
        userName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        persistIfNeeded()
    }

    func selectCurriculum(_ newCurriculum: Curriculum) {
        guard curriculum != newCurriculum else { return }
        curriculum = newCurriculum
        selectedSubjects = Set(SubjectLibrary.defaultSubjects(for: newCurriculum))
        persistIfNeeded()
    }

    func showSubjectSelection() {
        phase = .subjects
    }

    func toggleSubject(_ subject: String) {
        if selectedSubjects.contains(subject) {
            selectedSubjects.remove(subject)
        } else {
            selectedSubjects.insert(subject)
        }
        persistIfNeeded()
    }

    func toggleExtraLearning(_ item: String) {
        if selectedExtraLearning.contains(item) {
            selectedExtraLearning.remove(item)
        } else {
            selectedExtraLearning.insert(item)
        }
        persistIfNeeded()
    }

    func createLearningSpace() {
        if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .name
            return
        }
        if selectedSubjects.isEmpty {
            selectedSubjects = Set(SubjectLibrary.defaultSubjects(for: curriculum))
        }
        saveProfile()
        phase = .dashboard
    }

    func saveProfile() {
        storage.saveProfile(profile)
    }

    func resetLearningSpace() {
        storage.clearProfile()
        userName = ""
        curriculum = .ib
        selectedSubjects = Set(SubjectLibrary.defaultIBSubjects)
        selectedExtraLearning = ["语言学习"]
        selectedTab = .home
        phase = .welcome
    }

    private func persistIfNeeded() {
        guard phase == .dashboard else { return }
        saveProfile()
    }
}

extension PlanoraStore {
    static var previewOnboarding: PlanoraStore {
        PlanoraStore(storage: .preview, loadSavedProfile: false)
    }

    static var previewDashboard: PlanoraStore {
        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        store.userName = "Mitty"
        store.phase = .dashboard
        return store
    }
}
