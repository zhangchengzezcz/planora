import SwiftUI

struct ManageBacSettingsView: View {
    @State private var snapshot = ManageBacConnectionStorage.load()
    @State private var flow: ManageBacFlow?
    @State private var isShowingDisconnectConfirmation = false
    @State private var syncMode: ManageBacSyncMode = .quick
    @AppStorage(ManageBacSyncPolicy.messagesKey) private var syncMessages = true
    @AppStorage(ManageBacSyncPolicy.timetableKey) private var syncTimetable = true

    let store: PlanoraStore
    var onClose: (() -> Void)?

    init(store: PlanoraStore, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
    }

    var body: some View {
        Group {
#if os(macOS)
        macContent
#else
        mobileContent
#endif
        }
        .onReceive(NotificationCenter.default.publisher(for: .manageBacConnectionDidChange)) { _ in
            snapshot = ManageBacConnectionStorage.load()
        }
    }

#if os(macOS)
    private var macContent: some View {
        Form {
            Section("Import Recovery") {
                ImportRecoveryControls(store: store)
            }
            Section {
                connectionStatus
                if snapshot != nil { syncModePicker; fullSyncOptions }
                connectionActions
            } header: {
                Text(verbatim: "ManageBac")
            } footer: {
                Text(String(localized: "Import courses and tasks from the official ManageBac website."))
            }

            if let snapshot {
                Section(String(localized: "Last Sync")) {
                    LabeledContent(
                        String(localized: "Updated"),
                        value: snapshot.lastSyncDate.formatted(date: .abbreviated, time: .shortened)
                    )
                    LabeledContent(String(localized: "Sync Mode"), value: (snapshot.lastSyncMode ?? .full).title)
                    if let lastFull = snapshot.lastFullSyncDate {
                        LabeledContent(String(localized: "Last Full Sync"), value: lastFull.formatted(date: .abbreviated, time: .shortened))
                    }
                    LabeledContent(String(localized: "Stored Courses"), value: "\(snapshot.courseCount)")
                    LabeledContent(String(localized: "Tasks Read"), value: "\(snapshot.taskCount)")
                    if let skipped = snapshot.skippedItems, !skipped.isEmpty {
                        LabeledContent(String(localized: "Skipped Items"), value: skipped.joined(separator: ", "))
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("ManageBac")
        .toolbar {
            if let onClose {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done"), action: onClose)
                }
            }
        }
        .sheet(item: $flow) { flow in
            connectionFlow(flow)
                .frame(minWidth: 700, idealWidth: 760, minHeight: 640, idealHeight: 700)
        }
        .confirmationDialog(
            String(localized: "Disconnect ManageBac?"),
            isPresented: $isShowingDisconnectConfirmation,
            titleVisibility: .visible,
            actions: disconnectActions,
            message: disconnectMessage
        )
    }
#endif

    private var mobileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                header
                connectionCard
                ImportRecoveryControls(store: store)
                if let snapshot { syncDetails(snapshot) }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
#if os(iOS)
        .fullScreenCover(item: $flow) { flow in
            connectionFlow(flow)
        }
#endif
        .confirmationDialog(
            String(localized: "Disconnect ManageBac?"),
            isPresented: $isShowingDisconnectConfirmation,
            titleVisibility: .visible,
            actions: disconnectActions,
            message: disconnectMessage
        )
    }

    @ViewBuilder
    private var connectionStatus: some View {
        LabeledContent {
            Text(snapshot == nil ? String(localized: "Not Connected") : String(localized: "Connected"))
        } label: {
            Label(
                snapshot?.schoolHost ?? String(localized: "Connection"),
                systemImage: snapshot == nil ? "link.badge.plus" : "checkmark.circle.fill"
            )
        }
    }

    @ViewBuilder
    private var connectionActions: some View {
        if let snapshot {
            Button {
                flow = .sync(snapshot, syncMode)
            } label: {
                Label(syncMode.title, systemImage: syncMode.symbol)
            }
            Button(String(localized: "Disconnect"), role: .destructive) {
                isShowingDisconnectConfirmation = true
            }
        } else {
            Button {
                flow = .connect
            } label: {
                Label(String(localized: "Connect Account"), systemImage: "arrow.up.right.square")
            }
        }
    }

    private var syncModePicker: some View {
        PlanoraSegmentedPicker(selection: $syncMode, values: ManageBacSyncMode.allCases,
            title: String(localized: "Sync Mode"), label: { $0.title })
    }

    @ViewBuilder
    private var fullSyncOptions: some View {
        if syncMode == .full {
            Toggle(String(localized: "Messages"), isOn: $syncMessages)
            Toggle(String(localized: "Timetable"), isOn: $syncTimetable)
        }
    }

    @ViewBuilder
    private func connectionFlow(_ flow: ManageBacFlow) -> some View {
        ManageBacConnectionFlowView(store: store, flow: flow) { newSnapshot in
            snapshot = newSnapshot
            self.flow = nil
        } onCancel: {
            self.flow = nil
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
                        .background(
                            (snapshot == nil ? Color.planoraBlue : Color.planoraGreen).opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )

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
                    VStack(spacing: 12) {
                        syncModePicker
                        fullSyncOptions
                        Button {
                            flow = .sync(snapshot, syncMode)
                        } label: {
                            Label(syncMode.title, systemImage: syncMode.symbol)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)

                        Button(role: .destructive) {
                            isShowingDisconnectConfirmation = true
                        } label: {
                            Label(String(localized: "Disconnect"), systemImage: "link.badge.minus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glass)
                        .tint(.red)
                    }
                } else {
                    Button {
                        flow = .connect
                    } label: {
                        Label(String(localized: "Connect Account"), systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private func syncDetails(_ snapshot: ManageBacConnectionSnapshot) -> some View {
        DashboardSection(title: String(localized: "Last Sync")) {
            if let skipped = snapshot.skippedItems, !skipped.isEmpty {
                Label(String(localized: "Skipped Items") + ": " + skipped.joined(separator: ", "), systemImage: "exclamationmark.triangle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                SettingsRow(
                    icon: "clock.arrow.circlepath",
                    title: String(localized: "Updated"),
                    value: snapshot.lastSyncDate.formatted(date: .abbreviated, time: .shortened),
                    showsChevron: false
                )
                Divider().padding(.leading, 52)
                SettingsRow(icon: "arrow.triangle.2.circlepath", title: String(localized: "Sync Mode"),
                    value: (snapshot.lastSyncMode ?? .full).title, showsChevron: false)
                if let lastFull = snapshot.lastFullSyncDate {
                    Divider().padding(.leading, 52)
                    SettingsRow(icon: "clock", title: String(localized: "Last Full Sync"),
                        value: lastFull.formatted(date: .abbreviated, time: .shortened), showsChevron: false)
                }
                Divider().padding(.leading, 52)
                NavigationLink {
                    ManageBacCoursesView(store: store)
                } label: {
                    SettingsRow(
                        icon: "book.pages.fill",
                        title: String(localized: "Stored Courses"),
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

    @ViewBuilder
    private func disconnectActions() -> some View {
        Button(String(localized: "Disconnect"), role: .destructive) {
            disconnect()
        }
        Button(String(localized: "Cancel"), role: .cancel) { }
    }

    private func disconnectMessage() -> some View {
        Text(String(localized: "Your imported tasks will stay in Planora. The ManageBac login session will be removed."))
    }

    private func disconnect() {
        Task {
            let session = ManageBacWebSession()
            await session.clearWebsiteData()
            session.teardown()
            snapshot = nil
        }
    }
}
