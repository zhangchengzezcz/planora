import SwiftData
import SwiftUI

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

struct MacMainView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @State private var selection: MacDestination? = .home
    @State private var selectedTaskID: PlanoraTask.ID?
    @State private var isShowingCreateFlow = false
    @State private var searchText = ""
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MacSidebar(
                store: store,
                selection: $selection,
                selectedTaskID: $selectedTaskID,
                searchText: $searchText
            )
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            destinationView
                .navigationTitle((selection ?? .home).title)
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: searchText) { _, value in
            if !value.isEmpty {
                selectedTaskID = nil
                selection = .tasks
            }
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ControlGroup {
                    Button {
                        withAnimation(.snappy) {
                            columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                        }
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                    .help(String(localized: "Toggle Sidebar"))

                    Button {
                        isShowingCreateFlow = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help(String(localized: "New Task"))
                }
                .controlGroupStyle(.navigation)
            }
            ToolbarSpacer(.fixed, placement: .navigation)
        }
        .sheet(isPresented: $isShowingCreateFlow) {
            NavigationStack {
                CreateTaskView(
                    store: store,
                    onClose: { isShowingCreateFlow = false },
                    onComplete: {
                        isShowingCreateFlow = false
                        selection = .tasks
                    }
                )
            }
            .frame(minWidth: 680, idealWidth: 760, minHeight: 620, idealHeight: 740)
        }
        .overlay(alignment: .bottom) {
            if let undo = store.pendingDeletionUndo {
                MacDeletedTaskUndoBanner(count: undo.count) { restore(undo) }
                    .padding(16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: store.pendingDeletionUndo?.id)
        .onReceive(NotificationCenter.default.publisher(for: .planoraCreateTask)) { _ in
            isShowingCreateFlow = true
        }
        .onChange(of: store.selectedTab) { _, tab in
            if tab == .tasks { selection = .tasks }
        }
        .background { ManageBacAutomaticSyncHost(store: store) }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection ?? .home {
        case .home:
            MacHomeView(store: store, createTask: { isShowingCreateFlow = true })
        case .today:
            MacPlanningView(store: store, mode: .today)
        case .week:
            MacPlanningView(store: store, mode: .week)
        case .tasks:
            MacTaskWorkspaceView(store: store, searchText: searchText, selection: $selectedTaskID)
        case .courses:
            MacCoursesWorkspaceView(store: store)
        case .manageBac:
            ManageBacSettingsView(store: store)
        case .profile:
            MacProfileView(store: store)
        }
    }

    private func restore(_ undo: DeletedTaskUndo) {
        guard let restoredTasks = try? TaskBackupCodec.tasks(from: undo.json) else {
            store.clearDeletionUndo()
            return
        }
        for task in restoredTasks { modelContext.insert(task) }
        PlanoraTaskPersistence.save(modelContext)
        store.clearDeletionUndo()
        PlanoraTaskPersistence.reconcile(fallbackTasks: restoredTasks, in: modelContext)
    }
}

enum MacDestination: String, CaseIterable, Identifiable {
    case home
    case today
    case week
    case tasks
    case courses
    case manageBac
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .today: String(localized: "Today")
        case .week: String(localized: "This Week")
        case .tasks: String(localized: "Tasks")
        case .courses: String(localized: "Courses")
        case .manageBac: String(localized: "ManageBac")
        case .profile: String(localized: "Profile")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .today: "sun.max"
        case .week: "calendar"
        case .tasks: "checklist"
        case .courses: "books.vertical"
        case .manageBac: "arrow.triangle.2.circlepath"
        case .profile: "person.crop.circle"
        }
    }
}

private struct MacSidebar: View {
    @Bindable var store: PlanoraStore
    @Binding var selection: MacDestination?
    @Binding var selectedTaskID: PlanoraTask.ID?
    @Binding var searchText: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openSettings) private var openSettings
    @State private var isShowingAccountMenu = false
    @State private var isShowingHelp = false
    @Query(
        filter: #Predicate<PlanoraTask> { task in
            task.isPinned && !task.isCompleted && task.archivedDate == nil
        },
        sort: \PlanoraTask.createdDate,
        order: .reverse
    ) private var pinnedTaskResults: [PlanoraTask]

    private var pinnedTasks: [PlanoraTask] {
        Array(pinnedTaskResults.prefix(7))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Planora")
                .font(.title.weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            MacSidebarSearchField(
                text: $searchText,
                prompt: String(localized: "Search Tasks")
            ) {
                selectedTaskID = nil
                selection = .tasks
            }
            .frame(height: 24)
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            List(selection: destinationSelection) {
                Section {
                    link(.home)
                    link(.tasks)
                    link(.courses)
                    link(.manageBac)
                }

                Section(String(localized: "Planning")) {
                    link(.today)
                    link(.week)
                }

                if !pinnedTasks.isEmpty {
                    Section(String(localized: "Pinned Tasks")) {
                        ForEach(pinnedTasks) { task in
                            Button {
                                selectedTaskID = task.id
                                selection = .tasks
                            } label: {
                                Label {
                                    Text(task.title)
                                        .lineLimit(1)
                                } icon: {
                                    Image(systemName: task.type.symbol)
                                }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.primary)
                            .contextMenu {
                                Button(String(localized: "Unpin Task"), systemImage: "pin.slash") {
                                    task.isPinned = false
                                    PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack(spacing: 8) {
                Button {
                    isShowingAccountMenu.toggle()
                    isShowingHelp = false
                } label: {
                    HStack(spacing: 9) {
                        ProfileAvatarView(name: store.userName, size: 28)
                        Text(store.userName.isEmpty ? String(localized: "Profile") : store.userName)
                            .font(.headline)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    isShowingHelp.toggle()
                    isShowingAccountMenu = false
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help(String(localized: "Help and Feedback"))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .overlay(alignment: .bottomLeading) {
            Group {
                if isShowingAccountMenu {
                    MacAccountMenu(
                        store: store,
                        openProfile: {
                            isShowingAccountMenu = false
                            selectedTaskID = nil
                            selection = .profile
                        },
                        openSettings: {
                            isShowingAccountMenu = false
                            openSettings()
                        }
                    )
                } else if isShowingHelp {
                    MacHelpMenu()
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 56)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(10)
        }
        .animation(.snappy(duration: 0.2), value: isShowingAccountMenu)
        .animation(.snappy(duration: 0.2), value: isShowingHelp)
    }

    private var destinationSelection: Binding<MacDestination?> {
        Binding(
            get: { selection },
            set: { destination in
                selection = destination
                if destination == .tasks { selectedTaskID = nil }
            }
        )
    }

    private func link(_ destination: MacDestination) -> some View {
        Label(destination.title, systemImage: destination.systemImage)
            .tag(destination)
    }
}

private struct MacSidebarSearchField: NSViewRepresentable {
    @Binding var text: String
    let prompt: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = prompt
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.submit)
        field.sendsSearchStringImmediately = true
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        field.placeholderString = prompt
        context.coordinator.parent = self
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: MacSidebarSearchField

        init(parent: MacSidebarSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        @objc func submit() {
            parent.onSubmit()
        }
    }
}

private struct MacAccountMenu: View {
    let store: PlanoraStore
    let openProfile: () -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: openProfile) {
                HStack(spacing: 10) {
                    ProfileAvatarView(name: store.userName, size: 34)
                    Text(store.userName.isEmpty ? String(localized: "Profile") : store.userName)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .macMenuHoverStyle()

            Divider().padding(.horizontal, 8)

            Button(action: openSettings) {
                HStack {
                    Label(String(localized: "Settings"), systemImage: "gearshape")
                    Spacer()
                    Text("⌘,")
                        .foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(",", modifiers: .command)
            .macMenuHoverStyle()
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.7), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }
}

private struct MacHelpMenu: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(String(localized: "Help and Feedback"), systemImage: "questionmark.circle")
                .font(.headline)
            Divider()
            Text(String(localized: "Planora help is coming soon."))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.7), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.14), radius: 18, y: 8)
    }
}

private struct MacMenuHoverModifier: ViewModifier {
    @State private var isHovered = false

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isHovered ? Color.primary.opacity(0.07) : .clear)
                    .shadow(color: .black.opacity(isHovered ? 0.08 : 0), radius: 7, y: 2)
            }
            .onHover { isHovered = $0 }
    }
}

private extension View {
    func macMenuHoverStyle() -> some View {
        modifier(MacMenuHoverModifier())
    }
}

private struct MacProfileView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.openSettings) private var openSettings
    @State private var isChoosingAvatar = false
    @State private var avatarError: String?

    private var subjects: [String] {
        store.selectedSubjectTitles + store.selectedExtraLearningTitles
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 18) {
                    Button {
                        isChoosingAvatar = true
                    } label: {
                        ProfileAvatarView(name: store.userName, size: 72)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "pencil")
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 24, height: 24)
                                    .background(.regularMaterial, in: Circle())
                            }
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "Edit"))
                    .contextMenu {
                        if ProfileAvatarStorage.hasCustomAvatar {
                            Button(String(localized: "Use Initials"), systemImage: "person.crop.circle") {
                                removeAvatar()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 5) {
                        Text(store.userName.isEmpty ? String(localized: "Profile") : store.userName)
                            .font(.largeTitle.bold())
                        Text(verbatim: "\(store.curriculum.badge) · \(String(localized: "Learning Space"))")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(String(localized: "Settings"), systemImage: "gearshape") {
                        openSettings()
                    }
                    .buttonStyle(.glass)
                }

                GroupBox(String(localized: "Profile")) {
                    VStack(spacing: 0) {
                        HStack(spacing: 18) {
                            Text(String(localized: "Name"))
                            Spacer()
                            TextField(String(localized: "Name"), text: Binding(
                                get: { store.userName },
                                set: { store.updateUserName($0) }
                            ))
                            .labelsHidden()
                            .multilineTextAlignment(.trailing)
                            .frame(width: 260)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)

                        Divider()

                        HStack(spacing: 18) {
                            Text(String(localized: "Curriculum"))
                            Spacer()
                            Picker(String(localized: "Curriculum"), selection: Binding(
                                get: { store.curriculum },
                                set: { store.selectCurriculum($0) }
                            )) {
                                ForEach(Curriculum.allCases) { curriculum in
                                    Text(curriculum.title).tag(curriculum)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 300)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 12)
                    }
                }

                GroupBox(String(localized: "Current Subjects")) {
                    if subjects.isEmpty {
                        ContentUnavailableView(
                            String(localized: "No Subjects Yet"),
                            systemImage: "books.vertical"
                        )
                        .frame(minHeight: 150)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                            ForEach(subjects, id: \.self) { subject in
                                Label(PlanoraFormat.subjectDisplayName(subject), systemImage: "book.closed")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(12)
                                    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(6)
                    }
                }

                Text(String(localized: "Your profile stays on this device."))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $isChoosingAvatar,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let url = try result.get().first else { return }
                try ProfileAvatarStorage.save(from: url)
            } catch {
                avatarError = error.localizedDescription
            }
        }
        .alert(String(localized: "Avatar Update Failed"), isPresented: Binding(
            get: { avatarError != nil },
            set: { if !$0 { avatarError = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) { avatarError = nil }
        } message: {
            Text(avatarError ?? "")
        }
    }

    private func removeAvatar() {
        do {
            try ProfileAvatarStorage.remove()
        } catch {
            avatarError = error.localizedDescription
        }
    }
}

private struct MacDeletedTaskUndoBanner: View {
    let count: Int
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash")
            Text(PlanoraLocalization.format(String(localized: "tasks_deleted_format"), count))
            Button(String(localized: "Undo"), action: undo)
                .buttonStyle(.borderedProminent)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 8, y: 3)
    }
}
#endif
