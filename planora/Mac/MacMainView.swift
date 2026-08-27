import SwiftData
import SwiftUI

#if os(macOS)
import AppKit

struct MacMainView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @State private var selection: MacDestination? = .home
    @State private var selectedTaskID: PlanoraTask.ID?
    @State private var isShowingCreateFlow = false
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            MacSidebar(
                selection: $selection,
                selectedTaskID: $selectedTaskID,
                searchText: $searchText
            )
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
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingCreateFlow = true
                } label: {
                    Label(String(localized: "New Task"), systemImage: "plus")
                }
                .help(String(localized: "New Task"))
            }
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

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .today: String(localized: "Today")
        case .week: String(localized: "This Week")
        case .tasks: String(localized: "Tasks")
        case .courses: String(localized: "Courses")
        case .manageBac: String(localized: "ManageBac")
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
        }
    }
}

private struct MacSidebar: View {
    @Binding var selection: MacDestination?
    @Binding var selectedTaskID: PlanoraTask.ID?
    @Binding var searchText: String
    @Environment(\.modelContext) private var modelContext
    @State private var isSearchPresented = false
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
            HStack(spacing: 10) {
                Text("Planora")
                    .font(.title.weight(.bold))
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                Button {
                    withAnimation(.snappy) {
                        isSearchPresented.toggle()
                        if !isSearchPresented { searchText = "" }
                    }
                } label: {
                    Image(systemName: isSearchPresented ? "xmark" : "magnifyingglass")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(.quaternary, in: Circle())
                }
                .buttonStyle(.plain)
                .help(String(localized: "Search Tasks"))
            }
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if isSearchPresented {
                MacSidebarSearchField(
                    text: $searchText,
                    prompt: String(localized: "Search Tasks"),
                    requestsFocus: true
                ) {
                    selectedTaskID = nil
                    selection = .tasks
                }
                .frame(height: 24)
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

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
        }
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
    let requestsFocus: Bool
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
        if requestsFocus, field.window?.firstResponder !== field.currentEditor() {
            DispatchQueue.main.async {
                field.window?.makeFirstResponder(field)
            }
        }
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
