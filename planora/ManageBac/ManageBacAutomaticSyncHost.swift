import Combine
import SwiftData
import SwiftUI

struct ManageBacAutomaticSyncHost: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]
    @State private var session = ManageBacWebSession()
    @State private var snapshot = ManageBacConnectionStorage.load()
    @State private var lastAttemptDate: Date?
    @State private var isSyncing = false

    let store: PlanoraStore

    var body: some View {
        Group {
            if snapshot != nil {
                ManageBacWebView(session: session)
                    .frame(width: 1, height: 1)
                    .opacity(0.001)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .task {
            synchronizeIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .manageBacConnectionDidChange)) { _ in
            snapshot = ManageBacConnectionStorage.load()
            synchronizeIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            synchronizeIfNeeded()
        }
        .onChange(of: session.phase) { _, newPhase in
            switch newPhase {
            case .completed, .failed, .needsLogin:
                isSyncing = false
            default:
                break
            }
        }
    }

    private func synchronizeIfNeeded() {
        guard scenePhase == .active,
              !isSyncing,
              let snapshot else { return }

        let referenceDate = max(snapshot.lastSyncDate, lastAttemptDate ?? .distantPast)
        guard Date().timeIntervalSince(referenceDate) >= 5 * 60 else { return }

        isSyncing = true
        lastAttemptDate = Date()
        session.onSnapshotReady = importSnapshot
        session.startSilentSync(snapshot: snapshot)
    }

    private func importSnapshot(_ snapshot: ManageBacSyncSnapshot) throws -> ManageBacImportSummary {
        let currentTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? tasks
        let summary = try ManageBacTaskImporter.importSnapshot(
            snapshot,
            currentCurriculum: store.curriculum,
            existingTasks: currentTasks,
            into: modelContext
        )
        let importedCourses = (try? modelContext.fetch(FetchDescriptor<PlanoraCourse>())) ?? []
        for course in importedCourses where course.externalSource == .manageBac && !course.isArchived {
            store.addCustomSubject(course.displayName)
        }
        let refreshedTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? currentTasks
        PlanoraTaskPersistence.reconcile(tasks: refreshedTasks)
        return summary
    }
}
