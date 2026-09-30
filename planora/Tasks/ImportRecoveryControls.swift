import SwiftData
import SwiftUI

struct ImportRecoveryControls: View {
    let store: PlanoraStore
    @Environment(\.modelContext) private var context
    @State private var confirmRestore = false
    @State private var confirmClear = false
    @State private var errorMessage: String?
    @State private var hasRecovery = FileManager.default.fileExists(atPath: ImportRecovery.url.path)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Undo Latest Import", systemImage: "arrow.uturn.backward") {
                confirmRestore = true
            }
            .disabled(!hasRecovery)
            Button("Clear All Learning Data", systemImage: "trash", role: .destructive) {
                confirmClear = true
            }
        }
        .onAppear { hasRecovery = FileManager.default.fileExists(atPath: ImportRecovery.url.path) }
        .onReceive(NotificationCenter.default.publisher(for: .manageBacConnectionDidChange)) { _ in
            hasRecovery = FileManager.default.fileExists(atPath: ImportRecovery.url.path)
        }
        .confirmationDialog("Undo Latest Import?", isPresented: $confirmRestore, titleVisibility: .visible) {
            Button("Restore Before Import", role: .destructive) {
                perform {
                    let snapshot = try ImportRecovery.restore(context)
                    if let curriculum = snapshot.curriculum { store.curriculum = curriculum }
                    store.selectedSubjects = Set(snapshot.subjects ?? [])
                    store.pendingDeletionUndo = nil
                    store.saveProfile()
                }
            }
        } message: {
            Text("Restore all learning data to before the latest import or sync. Later learning-data edits will be replaced. Your name and avatar stay unchanged. ManageBac sync will be disconnected.")
        }
        .confirmationDialog("Clear All Learning Data?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear All Learning Data", role: .destructive) {
                perform {
                    try ImportRecovery.clear(context)
                    store.selectedSubjects = []
                    store.pendingDeletionUndo = nil
                    store.saveProfile()
                }
            }
        } message: {
            Text("Delete all tasks, courses, units, grades, teachers, messages, timetable and attendance, including personal tasks and local recovery backups. Your name, avatar and appearance stay unchanged. Sync will be disconnected. Export a backup first.")
        }
        .alert("Unable to Save Changes", isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })
        ) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func perform(_ operation: () throws -> Void) {
        do {
            try operation()
            hasRecovery = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
