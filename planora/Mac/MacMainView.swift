import SwiftData
import SwiftUI

#if os(macOS)
struct MacMainView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @State private var selection: MacDestination? = .home
    @State private var isShowingCreateFlow = false
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            MacSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
                .navigationTitle("Planora")
        } detail: {
            destinationView
                .navigationTitle((selection ?? .home).title)
        }
        .navigationSplitViewStyle(.balanced)
        .searchable(text: $searchText, placement: .sidebar, prompt: String(localized: "Search Tasks"))
        .onSubmit(of: .search) { selection = .tasks }
        .onChange(of: searchText) { _, value in
            if !value.isEmpty { selection = .tasks }
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
            MacTaskWorkspaceView(store: store, searchText: searchText)
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

    var body: some View {
        List(selection: $selection) {
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
        }
        .listStyle(.sidebar)
    }

    private func link(_ destination: MacDestination) -> some View {
        Label(destination.title, systemImage: destination.systemImage)
            .tag(destination)
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
