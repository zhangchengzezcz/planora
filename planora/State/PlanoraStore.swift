import Foundation
import Observation

@MainActor
@Observable
final class PlanoraStore {
    // MARK: - App State

    var phase: PlanoraPhase = .welcome
    var curriculum: Curriculum = .ib
    var selectedSubjects: Set<String> = SubjectLibrary.normalizedSubjects(
        for: .ib,
        subjects: Set(SubjectLibrary.defaultIBSubjects)
    )
    var selectedExtraLearning: Set<String> = ["语言学习"]
    var selectedTab: MainTab = .home
    var userName = ""
    var appearanceSettings = PlanoraAppearanceStorage.load()
    var pendingDeletionUndo: DeletedTaskUndo?

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
        selectedSubjects = SubjectLibrary.normalizedSubjects(
            for: profile.curriculum,
            subjects: Set(profile.subjects)
        )
        selectedExtraLearning = Set(profile.extraLearning)
        phase = .dashboard
    }

    // MARK: - Derived Profile Data

    var selectedSubjectTitles: [String] {
        let builtInSubjects = SubjectLibrary
            .subjects(for: curriculum)
            .map(\.title)
            .filter { selectedSubjects.contains($0) }

        return builtInSubjects + customSubjectTitles
    }

    var customSubjectTitles: [String] {
        selectedSubjects
            .filter { SubjectLibrary.isCustomSubject($0, for: curriculum) }
            .sorted()
    }

    var selectedExtraLearningTitles: [String] {
        let builtInItems = SubjectLibrary.builtInExtraLearning.filter {
            selectedExtraLearning.contains($0)
        }

        let customItems = selectedExtraLearning
            .filter { !SubjectLibrary.extraLearning.contains($0) }
            .sorted()

        return builtInItems + customItems
    }

    var customExtraLearningTitles: [String] {
        selectedExtraLearning
            .filter { !SubjectLibrary.extraLearning.contains($0) }
            .sorted()
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

    // MARK: - Onboarding Flow

    func showFeatureIntro() {
        phase = .features
    }

    func showNameEntry() {
        phase = .name
    }

    func showCurriculumSelection() {
        phase = .curriculum
    }

    // MARK: - Profile Mutations

    func updateUserName(_ newName: String) {
        userName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        persistIfNeeded()
    }

    func updateAppearance(_ update: (inout PlanoraAppearanceSettings) -> Void) {
        update(&appearanceSettings)
        PlanoraAppearanceStorage.save(appearanceSettings)
    }

    func resetAppearance() {
        appearanceSettings = .default
        PlanoraAppearanceStorage.save(appearanceSettings)
    }

    func selectCurriculum(_ newCurriculum: Curriculum) {
        guard curriculum != newCurriculum else { return }
        curriculum = newCurriculum
        selectedSubjects = SubjectLibrary.normalizedSubjects(
            for: newCurriculum,
            subjects: Set(SubjectLibrary.defaultSubjects(for: newCurriculum))
        )
        persistIfNeeded()
    }

    func showSubjectSelection() {
        phase = .subjects
    }

    func toggleSubject(_ subject: String) {
        guard !SubjectLibrary.isRequiredSubject(subject, for: curriculum) else {
            selectedSubjects.insert(subject)
            persistIfNeeded()
            return
        }

        if selectedSubjects.contains(subject) {
            selectedSubjects.remove(subject)
        } else {
            selectedSubjects.insert(subject)
        }
        persistIfNeeded()
    }

    func addCustomSubject(_ subject: String) {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty else { return }
        guard trimmedSubject != SubjectLibrary.customSubjectTrigger else { return }

        selectedSubjects.insert(trimmedSubject)
        selectedSubjects = SubjectLibrary.normalizedSubjects(for: curriculum, subjects: selectedSubjects)
        persistIfNeeded()
    }

    func toggleExtraLearning(_ item: String) {
        guard item != SubjectLibrary.customExtraLearningTrigger else { return }

        if selectedExtraLearning.contains(item) {
            selectedExtraLearning.remove(item)
        } else {
            selectedExtraLearning.insert(item)
        }
        persistIfNeeded()
    }

    func addCustomExtraLearning(_ item: String) {
        let trimmedItem = item.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedItem.isEmpty else { return }
        guard trimmedItem != SubjectLibrary.customExtraLearningTrigger else { return }

        selectedExtraLearning.insert(trimmedItem)
        persistIfNeeded()
    }

    // MARK: - Persistence

    func createLearningSpace() {
        if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            phase = .name
            return
        }
        selectedSubjects = SubjectLibrary.normalizedSubjects(for: curriculum, subjects: selectedSubjects)
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
        selectedSubjects = SubjectLibrary.normalizedSubjects(
            for: .ib,
            subjects: Set(SubjectLibrary.defaultIBSubjects)
        )
        selectedExtraLearning = ["语言学习"]
        selectedTab = .home
        phase = .welcome
    }

    func stageDeletedTasks(json: String, count: Int) {
        let undo = DeletedTaskUndo(json: json, count: count)
        pendingDeletionUndo = undo
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard self?.pendingDeletionUndo?.id == undo.id else { return }
            self?.pendingDeletionUndo = nil
        }
    }

    func clearDeletionUndo() {
        pendingDeletionUndo = nil
    }

    private func persistIfNeeded() {
        // Onboarding writes once at creation time. Dashboard edits persist immediately.
        guard phase == .dashboard else { return }
        saveProfile()
    }
}

struct DeletedTaskUndo: Identifiable, Equatable {
    let id = UUID()
    let json: String
    let count: Int
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
