import SwiftData
import SwiftUI

struct ContentView: View {
    @State private var store = PlanoraStore()

    var body: some View {
        PlanoraRootView(store: store)
    }
}

private struct PlanoraRootView: View {
    @Environment(\.modelContext) private var modelContext
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]
    @State private var importAlertTitle = ""
    @State private var importAlertMessage = ""
    @State private var isShowingImportAlert = false

    var body: some View {
        ZStack {
            PlanoraBackground()

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
        .environment(\.planoraAppearance, store.appearanceSettings)
        .environment(\.planoraTaskDisplay, store.taskDisplaySettings)
        .tint(store.appearanceSettings.accent.color)
        .preferredColorScheme(store.appearanceSettings.displayMode.colorScheme)
        .animation(.smooth(duration: 0.35), value: store.phase)
        .onOpenURL { url in
            importSharedBackup(from: url)
        }
        .alert(importAlertTitle, isPresented: $isShowingImportAlert) {
            Button(L("好", "OK"), role: .cancel) { }
        } message: {
            Text(importAlertMessage)
        }
    }

    private func importSharedBackup(from url: URL) {
        do {
            let preview = try TaskBackupImporter.preview(from: url, existingTasks: tasks)
            let result = try TaskBackupImporter.importTasks(
                preview,
                strategy: .skipDuplicates,
                existingTasks: tasks,
                into: modelContext
            )
            let refreshedTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? tasks
            Task { await TaskReminderScheduler.reconcile(tasks: refreshedTasks) }
            if store.phase == .dashboard {
                store.selectedTab = .tasks
            }

            presentImportAlert(
                title: L("导入完成", "Import Complete"),
                message: LF("backup_import_result_format", result.importedCount, result.skippedCount)
            )
        } catch {
            presentImportAlert(
                title: TaskBackupError.importFailureTitle(for: error),
                message: LF("backup_failure_format", error.localizedDescription)
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
    ContentView()
}

#Preview("Dashboard") {
    PlanoraRootView(store: .previewDashboard)
}
