import SwiftData
import SwiftUI

struct ContentView: View {
    let store: PlanoraStore

    init(store: PlanoraStore) {
        self.store = store
    }

    var body: some View {
        PlanoraRootView(store: store)
    }
}

private struct PlanoraRootView: View {
    @Environment(\.modelContext) private var modelContext
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]
    @Query(sort: \PlanoraCourse.displayName) private var courses: [PlanoraCourse]
    @Query(sort: \PlanoraUnit.title) private var units: [PlanoraUnit]
    @Query(sort: \PlanoraTopic.title) private var topics: [PlanoraTopic]
    @Query(sort: \PlanoraAssessment.date, order: .reverse) private var assessments: [PlanoraAssessment]
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var isShowingImportAlert = false

    var body: some View {
        ZStack {
            rootBackground

            Group {
                switch store.phase {
                case .welcome:
                    WelcomeView {
                        store.showFeatureIntro()
                    }
                case .features:
                    FeatureIntroView {
                        store.showNameEntry()
                    }
                case .name:
                    UserNameEntryView(store: store)
                case .curriculum:
                    CurriculumSelectionView(store: store)
                case .subjects:
                    SubjectSelectionView(store: store)
                case .dashboard:
                    MainAppView(store: store)
                }
            }
            .transition(.opacity.combined(with: .scale(scale: 0.985)))
        }
        .environment(\.planoraAppearance, effectiveAppearance)
        .environment(\.planoraTaskDisplay, store.taskDisplaySettings)
        .tint(effectiveTint)
        .preferredColorScheme(effectiveColorScheme)
        .animation(.smooth(duration: 0.35), value: store.phase)
        .onOpenURL { url in
            importSharedBackup(from: url)
        }
        .alert(importAlertTitle, isPresented: $isShowingImportAlert) {
            Button(String(localized: "OK"), role: .cancel) { }
        } message: {
            Text(importAlertMessage)
        }
    }

    @ViewBuilder
    private var rootBackground: some View {
#if os(macOS)
        if store.phase == .dashboard {
            Color(nsColor: .windowBackgroundColor)
        } else {
            PlanoraBackground()
        }
#else
        PlanoraBackground()
#endif
    }

    private var effectiveAppearance: PlanoraAppearanceSettings {
        store.appearanceSettings
    }

    private var effectiveTint: Color {
        store.appearanceSettings.accent.color
    }

    private var effectiveColorScheme: ColorScheme? {
        store.appearanceSettings.displayMode.colorScheme
    }

    private func importSharedBackup(from url: URL) {
        do {
            let preview = try TaskBackupImporter.preview(
                from: url,
                existingTasks: tasks,
                existingCourses: courses,
                existingUnits: units
            )
            let result = try TaskBackupImporter.importTasks(
                preview,
                strategy: .skipDuplicates,
                existingTasks: tasks,
                existingCourses: courses,
                existingUnits: units,
                existingTopics: topics,
                existingAssessments: assessments,
                into: modelContext
            )
            PlanoraTaskPersistence.reconcile(fallbackTasks: tasks, in: modelContext)
            if store.phase == .dashboard {
                store.selectedTab = .tasks
            }

            presentImportAlert(
                title: String(localized: "Import Complete"),
                message: PlanoraLocalization.format(String(localized: "backup_import_result_format"), result.importedCount, result.skippedCount)
            )
        } catch {
            presentImportAlert(
                title: TaskBackupError.importFailureTitle(for: error),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func presentImportAlert(title: String, message: String) {
        importAlertTitle = title
        importAlertMessage = message
        isShowingImportAlert = true
    }
}

#Preview("Fresh Launch") {
    ContentView(store: .previewOnboarding)
}

#Preview("Dashboard") {
    PlanoraRootView(store: .previewDashboard)
}
