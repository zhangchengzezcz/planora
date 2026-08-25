import SwiftData
import SwiftUI

struct ManageBacSettingsView: View {
    @State private var snapshot = ManageBacConnectionStorage.load()
    @State private var flow: ManageBacFlow?
    @State private var isShowingDisconnectConfirmation = false

    let store: PlanoraStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                connectionCard

                if let snapshot {
                    syncDetails(snapshot)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
        .fullScreenCover(item: $flow) { flow in
            ManageBacConnectionFlowView(store: store, flow: flow) { newSnapshot in
                snapshot = newSnapshot
                self.flow = nil
            } onCancel: {
                self.flow = nil
            }
        }
        .confirmationDialog(
            String(localized: "Disconnect ManageBac?"),
            isPresented: $isShowingDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Disconnect"), role: .destructive) {
                disconnect()
            }
            Button(String(localized: "Cancel"), role: .cancel) { }
        } message: {
            Text(String(localized: "Your imported tasks will stay in Planora. The ManageBac login session will be removed."))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "ManageBac")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.planoraInk)

            Text(String(localized: "Import courses and tasks from the official ManageBac website."))
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private var connectionCard: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 14) {
                    Image(systemName: snapshot == nil ? "link.badge.plus" : "checkmark.circle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(snapshot == nil ? Color.planoraBlue : Color.planoraGreen)
                        .frame(width: 46, height: 46)
                        .background((snapshot == nil ? Color.planoraBlue : Color.planoraGreen).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(snapshot == nil ? String(localized: "Not Connected") : String(localized: "Connected"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.planoraInk)

                        Text(snapshot?.schoolHost ?? String(localized: "Sign in once to import your learning schedule."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                if let snapshot {
                    HStack(spacing: 12) {
                        Button {
                            flow = .sync(snapshot)
                        } label: {
                            Label(String(localized: "Sync Now"), systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(role: .destructive) {
                            isShowingDisconnectConfirmation = true
                        } label: {
                            Image(systemName: "link.badge.minus")
                                .frame(width: 28, height: 20)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(String(localized: "Disconnect"))
                    }
                } else {
                    Button {
                        flow = .connect
                    } label: {
                        Label(String(localized: "Connect Account"), systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }

    private func syncDetails(_ snapshot: ManageBacConnectionSnapshot) -> some View {
        DashboardSection(title: String(localized: "Last Sync")) {
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "Updated"),
                    value: snapshot.lastSyncDate.formatted(date: .abbreviated, time: .shortened),
                    showsChevron: false
                )
                Divider().padding(.leading, 52)
                NavigationLink {
                    ManageBacCoursesView(store: store)
                } label: {
                    SettingsRow(
                        icon: "book.pages.fill",
                        title: String(localized: "Courses"),
                        value: "\(snapshot.courseCount)",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
                SettingsRow(
                    icon: "checklist",
                    title: String(localized: "Tasks Read"),
                    value: "\(snapshot.taskCount)",
                    showsChevron: false
                )
            }
        }
    }

    private func disconnect() {
        Task {
            let session = ManageBacWebSession()
            await session.clearWebsiteData()
            snapshot = nil
        }
    }
}

enum ManageBacFlow: Identifiable {
    case connect
    case sync(ManageBacConnectionSnapshot)

    var id: String {
        switch self {
        case .connect: "connect"
        case .sync: "sync"
        }
    }
}

struct ManageBacConnectionFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]
    @State private var session = ManageBacWebSession()
    @State private var hasStarted = false

    let store: PlanoraStore
    let flow: ManageBacFlow
    let onComplete: (ManageBacConnectionSnapshot) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            ManageBacWebView(session: session)
                .opacity(session.phase.showsOfficialLogin ? 1 : 0.001)
                .allowsHitTesting(session.phase.showsOfficialLogin)
                .accessibilityHidden(!session.phase.showsOfficialLogin)

            if !session.phase.showsOfficialLogin {
                PlanoraBackground().ignoresSafeArea()
                progressContent
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            connectionHeader
        }
        .onAppear(perform: startIfNeeded)
    }

    private var connectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "ManageBac")
                    .font(.headline.weight(.bold))
                Text(session.phase.showsOfficialLogin ? String(localized: "Official Sign In") : String(localized: "Reading Learning Data"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: cancel) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.bold))
                    .frame(width: 38, height: 38)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .accessibilityLabel(String(localized: "Close"))
        }
        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    @ViewBuilder
    private var progressContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(statusTitle)
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)
                    Text(statusMessage)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ProgressView(value: Double(session.completedStepCount), total: Double(syncSteps.count))
                    .tint(Color.planoraBlue)

                VStack(spacing: 0) {
                    ForEach(Array(syncSteps.enumerated()), id: \.offset) { index, title in
                        ManageBacSyncStepRow(
                            title: title,
                            state: stepState(at: index)
                        )
                        if index < syncSteps.count - 1 {
                            Divider().padding(.leading, 44)
                        }
                    }
                }

                if case .completed = session.phase {
                    Button(String(localized: "Done"), action: finish)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                } else if case .needsLogin = session.phase {
                    Button(String(localized: "Connect Again")) { session.startInteractiveConnection() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                } else if case .failed = session.phase {
                    Button(String(localized: "Try Again"), action: start)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
            .padding(.top, 34)
            .padding(.bottom, 36)
        }
    }

    private var syncSteps: [String] {
        [
            String(localized: "Verify student account"),
            String(localized: "Read courses"),
            String(localized: "Identify curriculum"),
            String(localized: "Read teachers and units"),
            String(localized: "Read tasks and deadlines"),
            String(localized: "Compare with Planora"),
            String(localized: "Apply safe updates"),
            String(localized: "Finish sync")
        ]
    }

    private func stepState(at index: Int) -> ManageBacSyncStepState {
        if index < session.completedStepCount { return .completed }
        if case .completed = session.phase { return .completed }
        if case .failed = session.phase, index == session.completedStepCount { return .failed }
        if case .needsLogin = session.phase, index == session.completedStepCount { return .warning }
        if index == session.completedStepCount { return .active }
        return .waiting
    }

    private var statusTitle: String {
        switch session.phase {
        case .idle: String(localized: "Preparing Connection")
        case .authenticating: String(localized: "Official Sign In")
        case .verifying: String(localized: "Checking Account")
        case .loadingCourses: String(localized: "Reading Courses")
        case .identifyingCurriculum: String(localized: "Identifying Curriculum")
        case .loadingUnits: String(localized: "Reading Teachers and Units")
        case .loadingTasks: String(localized: "Reading Tasks and Deadlines")
        case .comparing: String(localized: "Comparing Changes")
        case .importing: String(localized: "Updating Planora")
        case .completed: String(localized: "ManageBac Connected")
        case .needsLogin: String(localized: "Sign In Required")
        case .failed: String(localized: "Sync Paused")
        }
    }

    private var statusMessage: String {
        switch session.phase {
        case .completed(let summary):
            PlanoraLocalization.format(
                String(localized: "managebac_import_summary_format"),
                summary.courseCount,
                summary.importedCount,
                summary.updatedCount
            )
        case .needsLogin:
            String(localized: "Your ManageBac session has expired. Please connect again.")
        case .failed(let error):
            error.localizedDescription
        default:
            String(localized: "Planora is reading only the courses and tasks shown to your student account.")
        }
    }

    private func startIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        session.onSnapshotReady = importSnapshot
        start()
    }

    private func start() {
        session.onSnapshotReady = importSnapshot
        switch flow {
        case .connect:
            session.startInteractiveConnection()
        case .sync(let snapshot):
            session.startSilentSync(snapshot: snapshot)
        }
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

    private func finish() {
        guard case .completed = session.phase,
              let snapshot = ManageBacConnectionStorage.load() else { return }
        onComplete(snapshot)
    }

    private func cancel() {
        session.cancel()
        onCancel()
    }
}

private enum ManageBacSyncStepState {
    case waiting
    case active
    case completed
    case warning
    case failed
}

private struct ManageBacSyncStepRow: View {
    let title: String
    let state: ManageBacSyncStepState

    var body: some View {
        HStack(spacing: 14) {
            Group {
                switch state {
                case .waiting:
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                case .active:
                    ProgressView().controlSize(.small).tint(Color.planoraBlue)
                case .completed:
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.planoraGreen)
                case .warning:
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.planoraAmber)
                case .failed:
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.title3.weight(.semibold))
            .frame(width: 28, height: 28)

            Text(title)
                .font(.body.weight(state == .active ? .semibold : .regular))
                .foregroundStyle(state == .waiting ? .secondary : Color.planoraInk)
            Spacer()
        }
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }
}
