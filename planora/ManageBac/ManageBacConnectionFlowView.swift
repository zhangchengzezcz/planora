import SwiftData
import SwiftUI

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
    @State private var session: ManageBacWebSession
    @State private var hasStarted = false

    let store: PlanoraStore
    let flow: ManageBacFlow
    let onComplete: (ManageBacConnectionSnapshot) -> Void
    let onCancel: () -> Void

    @MainActor init(
        store: PlanoraStore,
        flow: ManageBacFlow,
        session: ManageBacWebSession? = nil,
        onComplete: @escaping (ManageBacConnectionSnapshot) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.store = store
        self.flow = flow
        self.onComplete = onComplete
        self.onCancel = onCancel
        _session = State(initialValue: session ?? ManageBacWebSession())
    }

    var body: some View {
#if os(macOS)
        NavigationStack {
            flowContent
                .navigationTitle(navigationTitle)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        if isCompleted {
                            Button(String(localized: "Done"), action: finish)
                        } else {
                            Button(String(localized: "Cancel"), action: cancel)
                        }
                    }
                }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear(perform: startIfNeeded)
        .onDisappear(perform: session.teardown)
#else
        flowContent
            .safeAreaInset(edge: .top, spacing: 0) {
                connectionHeader
            }
            .onAppear(perform: startIfNeeded)
            .onDisappear(perform: session.teardown)
#endif
    }

    private var flowContent: some View {
        ZStack {
            ManageBacWebView(session: session)
                .opacity(session.phase.showsOfficialLogin ? 1 : 0.001)
                .allowsHitTesting(session.phase.showsOfficialLogin)
                .accessibilityHidden(!session.phase.showsOfficialLogin)

            if !session.phase.showsOfficialLogin {
#if os(iOS)
                PlanoraBackground().ignoresSafeArea()
#endif
                progressContent
            }
        }
    }

    private var navigationTitle: String {
        session.phase.showsOfficialLogin
            ? String(localized: "Official Sign In")
            : String(localized: "ManageBac Sync")
    }

#if os(iOS)
    private var connectionHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "ManageBac")
                    .font(.headline.weight(.bold))
                Text(navigationTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isCompleted {
                Button(String(localized: "Done"), action: finish)
                    .fontWeight(.semibold)
                    .buttonStyle(.borderedProminent)
            } else {
                Button(String(localized: "Cancel"), action: cancel)
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
#endif

    private var progressContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                statusHeader
                if isCompleted {
                    completionSummary
                    courseSummary
                    DisclosureGroup(String(localized: "Sync Progress")) {
                        stepRows
                    }
                } else {
                    stepList
                }
                recoveryAction
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 28)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var courseSummary: some View {
        if isCompleted, !session.courses.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "Courses"))
                    .font(.headline)
                ForEach(session.courses, id: \.remoteIdentifier) { course in
                    Text(verbatim: course.name)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Divider()
                }
            }
        }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(statusTitle)
                    .font(.title.weight(.semibold))
                Spacer()
                Text("\(min(session.completedStepCount, syncSteps.count)) / \(syncSteps.count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(
                value: Double(min(session.completedStepCount, syncSteps.count)),
                total: Double(syncSteps.count)
            )
        }
    }

    @ViewBuilder
    private var stepList: some View {
#if os(macOS)
        GroupBox(String(localized: "Sync Progress")) {
            stepRows.padding(6)
        }
#else
        GlassPanel {
            stepRows
        }
#endif
    }

    private var stepRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(syncSteps.enumerated()), id: \.offset) { index, title in
                ManageBacSyncStepRow(title: title, state: stepState(at: index))
                if index < syncSteps.count - 1 {
                    Divider().padding(.leading, 42)
                }
            }
        }
    }

    @ViewBuilder
    private var completionSummary: some View {
        if case .completed(let summary) = session.phase {
#if os(macOS)
            GroupBox(String(localized: "Imported Content")) {
                summaryGrid(summary).padding(8)
            }
#else
            GlassPanel {
                summaryGrid(summary)
            }
#endif
        }
    }

    @ViewBuilder
    private func summaryGrid(_ summary: ManageBacImportSummary) -> some View {
#if os(iOS)
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent(String(localized: "Courses"), value: "\(summary.courseCount)")
            LabeledContent(String(localized: "Units"), value: "\(summary.unitCount)")
            LabeledContent(String(localized: "New Tasks"), value: "\(summary.importedCount)")
            LabeledContent(String(localized: "Updated Tasks"), value: "\(summary.updatedCount)")
            LabeledContent(String(localized: "Messages"), value: "\(summary.messageCount)")
            LabeledContent(String(localized: "Timetable"), value: "\(summary.scheduleCount)")
            if summary.reviewCount > 0 {
                LabeledContent(String(localized: "Needs Review"), value: "\(summary.reviewCount)")
            }
        }
        .monospacedDigit()
#else
        Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 10) {
            GridRow {
                LabeledContent(String(localized: "Courses"), value: "\(summary.courseCount)")
                LabeledContent(String(localized: "Units"), value: "\(summary.unitCount)")
            }
            GridRow {
                LabeledContent(String(localized: "New Tasks"), value: "\(summary.importedCount)")
                LabeledContent(String(localized: "Updated Tasks"), value: "\(summary.updatedCount)")
            }
            GridRow {
                LabeledContent(String(localized: "Messages"), value: "\(summary.messageCount)")
                LabeledContent(String(localized: "Timetable"), value: "\(summary.scheduleCount)")
            }
            if summary.reviewCount > 0 {
                GridRow {
                    LabeledContent(String(localized: "Needs Review"), value: "\(summary.reviewCount)")
                }
            }
        }
        .monospacedDigit()
#endif
    }

    @ViewBuilder
    private var recoveryAction: some View {
        if case .needsLogin = session.phase {
            Button(String(localized: "Connect Again")) {
                session.startInteractiveConnection()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        } else if case .failed = session.phase {
            Button(String(localized: "Try Again"), action: start)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    private var isCompleted: Bool {
        if case .completed = session.phase { return true }
        return false
    }

    private var syncSteps: [String] {
        [
            String(localized: "Verify student account"),
            String(localized: "Read courses"),
            String(localized: "Identify curriculum"),
            String(localized: "Read teachers and units"),
            String(localized: "Read tasks and deadlines"),
            String(localized: "Read messages and timetable"),
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
        case .loadingWorkspace: String(localized: "Reading Messages and Timetable")
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
        guard session.phase == .idle else { return }
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
        session.teardown()
        onComplete(snapshot)
    }

    private func cancel() {
        session.cancel()
        session.teardown()
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
        HStack(spacing: 12) {
            stateIcon
                .frame(width: 24, height: 24)

            Text(title)
                .font(.body.weight(state == .active ? .semibold : .regular))
                .foregroundStyle(state == .waiting ? .secondary : .primary)
            Spacer()
        }
        .frame(minHeight: 42)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .waiting:
            Image(systemName: "circle")
                .foregroundStyle(.tertiary)
        case .active:
            ProgressView().controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }
}
