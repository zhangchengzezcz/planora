import SwiftData
import SwiftUI

enum ManageBacFlow: Identifiable {
    case connect
    case sync(ManageBacConnectionSnapshot, ManageBacSyncMode = .full)

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
                            if case .failed = session.phase {
                                Button(String(localized: "Try Again"), action: retry)
                            }
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
            .safeAreaBar(edge: .top, spacing: 0) {
                connectionHeader
            }
            .scrollEdgeEffectStyle(.automatic, for: .top)
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
                Button(action: finish) {
                    Text(String(localized: "Done"))
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, 16)
                        .glassEffect(.regular.interactive(), in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            } else {
                if case .failed = session.phase {
                    Button(String(localized: "Try Again"), action: retry)
                        #if os(macOS)
                        .buttonStyle(.borderedProminent)
                        #else
                        .buttonStyle(.glass)
                        #endif
                }
                Button(String(localized: "Cancel"), action: cancel)
                    #if os(macOS)
                    .buttonStyle(.bordered)
                    #else
                    .buttonStyle(.glass)
                    #endif
            }
        }
        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
        .padding(.vertical, 10)
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
                Text(String(localized: "Courses Read"))
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
                Text("\(displayedProgress) / \(displayedStepIndices.count)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            Text(statusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ProgressView(
                value: Double(displayedProgress),
                total: Double(displayedStepIndices.count)
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
            ForEach(displayedStepIndices, id: \.self) { index in
                ManageBacSyncStepRow(title: syncSteps[index], state: stepState(at: index))
                if index != displayedStepIndices.last {
                    Divider().padding(.leading, 42)
                }
            }
            Divider().padding(.leading, 42)
            HStack {
                Label(String(localized: "Synced Week Attendance"), systemImage: "person.badge.clock")
                Spacer()
                Text(attendanceText(session.attendanceOverview))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var completionSummary: some View {
        if case .completed(let summary) = session.phase {
#if os(macOS)
            GroupBox(String(localized: "Sync Results")) {
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
            LabeledContent(String(localized: "Sync Mode"), value: session.syncMode.title)
            LabeledContent(String(localized: "Courses Read"), value: "\(session.courses.count)")
            LabeledContent(String(localized: "Units Read"), value: unitsReadText)
            LabeledContent(String(localized: "New Tasks"), value: "\(summary.importedCount)")
            LabeledContent(String(localized: "Tasks Refreshed"), value: "\(summary.updatedCount)")
            LabeledContent(String(localized: "Messages Read"), value: messagesReadText(summary))
            LabeledContent(String(localized: "Lessons Read"), value: lessonsReadText(summary))
            LabeledContent(String(localized: "Synced Week Attendance"), value: attendanceText(summary.attendanceOverview))
            if summary.reviewCount > 0 {
                LabeledContent(String(localized: "Needs Review"), value: "\(summary.reviewCount)")
            }
        }
        .monospacedDigit()
#else
        Grid(alignment: .leading, horizontalSpacing: 26, verticalSpacing: 10) {
            GridRow {
                LabeledContent(String(localized: "Sync Mode"), value: session.syncMode.title)
            }
            GridRow {
                LabeledContent(String(localized: "Courses Read"), value: "\(session.courses.count)")
                LabeledContent(String(localized: "Units Read"), value: unitsReadText)
            }
            GridRow {
                LabeledContent(String(localized: "New Tasks"), value: "\(summary.importedCount)")
                LabeledContent(String(localized: "Tasks Refreshed"), value: "\(summary.updatedCount)")
            }
            GridRow {
                LabeledContent(String(localized: "Messages Read"), value: messagesReadText(summary))
                LabeledContent(String(localized: "Lessons Read"), value: lessonsReadText(summary))
            }
            GridRow {
                LabeledContent(String(localized: "Synced Week Attendance"), value: attendanceText(summary.attendanceOverview))
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

    private func attendanceText(_ overview: ManageBacAttendanceOverview?) -> String {
        ManageBacSyncPresentation.attendance(overview)
    }

    private var unitsReadText: String {
        session.syncMode == .quick ? String(localized: "Not Rescanned") : "\(session.units.count)"
    }

    private func messagesReadText(_ summary: ManageBacImportSummary) -> String {
        session.skippedItems.contains(String(localized: "Messages")) ? String(localized: "Not Read") : "\(summary.messageCount)"
    }

    private func lessonsReadText(_ summary: ManageBacImportSummary) -> String {
        session.skippedItems.contains(String(localized: "Timetable")) ? String(localized: "Not Read") : "\(summary.scheduleCount)"
    }

    @ViewBuilder
    private var recoveryAction: some View {
        if case .needsLogin = session.phase {
            Button(String(localized: "Connect Again")) {
                session.startInteractiveConnection()
            }
            #if os(macOS)
            .buttonStyle(.borderedProminent)
            #else
            .buttonStyle(.glass)
            #endif
            .controlSize(.large)
        } else if case .failed = session.phase {
            VStack(alignment: .leading, spacing: 12) {
                if let title = session.failedItemTitle {
                    Text(title).font(.headline)
                    Text(String(localized: "Skipping keeps existing data for this item."))
                        .foregroundStyle(.secondary)
                }
                HStack {
                    if session.recoveryPhase != nil && session.recoveryPhase != .importing {
                        Button(String(localized: "Skip This Item")) { session.skipFailedStep() }
                            #if os(macOS)
                            .buttonStyle(.bordered)
                            #else
                            .buttonStyle(.glass)
                            #endif
                    }
                    Button(String(localized: "Cancel"), action: cancel)
                        #if os(macOS)
                        .buttonStyle(.bordered)
                        #else
                        .buttonStyle(.glass)
                        #endif
                }
                .controlSize(.large)
            }
        }
        if !session.skippedItems.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label(String(localized: "Skipped Items"), systemImage: "exclamationmark.triangle")
                    .font(.headline)
                ForEach(Array(session.skippedItems.enumerated()), id: \.offset) { _, title in
                    Text(title)
                }
            }
            .foregroundStyle(.secondary)
        }
    }

    private func retry() {
        if session.recoveryPhase != nil { session.retryFailedStep() }
        else { start() }
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
            session.syncMode == .quick ? String(localized: "Keep existing teachers and units") : String(localized: "Read teachers and units"),
            String(localized: "Read tasks and deadlines"),
            String(localized: "Read messages and timetable"),
            String(localized: "Prepare Local Update"),
            String(localized: "Save Changes"),
            String(localized: "Finish sync")
        ]
    }

    private var displayedStepIndices: [Int] { ManageBacSyncPresentation.stepIndices(mode: session.syncMode) }
    private var displayedProgress: Int {
        ManageBacSyncPresentation.progress(mode: session.syncMode, completed: session.completedStepCount)
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
        case .comparing: String(localized: "Prepare Local Update")
        case .importing: String(localized: "Updating Planora")
        case .completed: session.syncMode == .quick ? String(localized: "Quick Sync Complete") : String(localized: "Full Sync Complete")
        case .needsLogin: String(localized: "Sign In Required")
        case .failed: String(localized: "Sync Paused")
        }
    }

    private var statusMessage: String {
        switch session.phase {
        case .completed(let summary):
            PlanoraLocalization.format(
                String(localized: "managebac_sync_results_format"),
                session.courses.count,
                summary.importedCount,
                summary.updatedCount
            )
        case .needsLogin:
            String(localized: "Your ManageBac session has expired. Please connect again.")
        case .failed(let error):
            error.localizedDescription
        default:
            session.syncMode == .quick
                ? String(localized: "Refreshing task lists, current messages and this week's timetable.")
                : String(localized: "Reading course tasks, teachers, units, messages and timetable.")
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
        case .sync(let snapshot, let syncMode):
            if let current = ManageBacConnectionStorage.load(),
               snapshot.belongsToSameConnection(as: current) {
                session.startSilentSync(snapshot: current, syncMode: syncMode)
            } else {
                session.startInteractiveConnection()
            }
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
