import SwiftUI

struct ManageBacSettingsView: View {
    @State private var snapshot = ManageBacConnectionStorage.load()
    @State private var flow: ManageBacFlow?
    @State private var isShowingDisconnectConfirmation = false

    let store: PlanoraStore
    var onClose: (() -> Void)?

    init(store: PlanoraStore, onClose: (() -> Void)? = nil) {
        self.store = store
        self.onClose = onClose
    }

    var body: some View {
#if os(macOS)
        macContent
#else
        mobileContent
#endif
    }

#if os(macOS)
    private var macContent: some View {
        Form {
            Section {
                connectionStatus
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
                    LabeledContent(String(localized: "Courses"), value: "\(snapshot.courseCount)")
                    LabeledContent(String(localized: "Tasks Read"), value: "\(snapshot.taskCount)")
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
                flow = .sync(snapshot)
            } label: {
                Label(String(localized: "Sync Now"), systemImage: "arrow.clockwise")
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
