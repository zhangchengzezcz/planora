import SwiftData
import SwiftUI

#if targetEnvironment(macCatalyst)
struct MacMainView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @State private var selection: MacDestination? = .home
    @State private var isShowingCreateFlow = false
    @State private var searchFocusRequestID = 0

    var body: some View {
        NavigationSplitView {
            MacSidebar(store: store, selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 300)
        } detail: {
            NavigationStack {
                destinationView
            }
            .id(selection)
        }
        .navigationSplitViewStyle(.balanced)
        .background(PlanoraBackground())
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Button {
                    selection = .search
                    searchFocusRequestID += 1
                } label: {
                    Label(String(localized: "Search"), systemImage: "magnifyingglass")
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingCreateFlow = true
                } label: {
                    Label(String(localized: "New Task"), systemImage: "plus")
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isShowingCreateFlow) {
            NavigationStack {
                CreateTaskView(
                    store: store,
                    onClose: { isShowingCreateFlow = false },
                    onComplete: {
                        isShowingCreateFlow = false
                        selection = .home
                    }
                )
            }
            .frame(minWidth: 680, idealWidth: 760, minHeight: 620, idealHeight: 760)
        }
        .overlay(alignment: .bottom) {
            if let undo = store.pendingDeletionUndo {
                MacDeletedTaskUndoBanner(count: undo.count) {
                    restore(undo)
                }
                .padding(20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: store.pendingDeletionUndo?.id)
        .onChange(of: store.selectedTab) { _, tab in
            guard tab == .tasks else { return }
            selection = .tasks
        }
        .background {
            ManageBacAutomaticSyncHost(store: store)
        }
    }

    @ViewBuilder
    private var destinationView: some View {
        switch selection ?? .home {
        case .home:
            HomeDashboardView(store: store) {
                isShowingCreateFlow = true
            }
        case .today:
            TodayPlanningView(store: store)
        case .week:
            WeekPlanningView(store: store)
        case .tasks:
            TaskListView(store: store)
        case .search:
            EventSearchView(store: store, isActive: true, focusRequestID: searchFocusRequestID)
                .onAppear { searchFocusRequestID += 1 }
        case .courses:
            ManageBacCoursesView(store: store)
        case .profile:
            ProfileView(store: store)
        }
    }

    private func restore(_ undo: DeletedTaskUndo) {
        guard let restoredTasks = try? TaskBackupCodec.tasks(from: undo.json) else {
            store.clearDeletionUndo()
            return
        }
        for task in restoredTasks { modelContext.insert(task) }
        let currentTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? restoredTasks
        for restoredTask in restoredTasks {
            guard let seriesID = restoredTask.recurrenceSeriesID else { continue }
            let series = currentTasks.filter { $0.recurrenceSeriesID == seriesID }
            RecurringTaskEngine.restoreSeriesRule(from: restoredTask, in: series)
            RecurringTaskEngine.includeOccurrence(restoredTask, in: series)
        }
        PlanoraTaskPersistence.save(modelContext)
        store.clearDeletionUndo()
        PlanoraTaskPersistence.reconcile(fallbackTasks: currentTasks, in: modelContext)
    }
}

private enum MacDestination: String, CaseIterable, Identifiable {
    case home
    case today
    case week
    case tasks
    case search
    case courses
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: String(localized: "Home")
        case .today: String(localized: "Today")
        case .week: String(localized: "This Week")
        case .tasks: String(localized: "Tasks")
        case .search: String(localized: "Search")
        case .courses: String(localized: "ManageBac Courses")
        case .profile: String(localized: "Me")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .today: "sun.max.fill"
        case .week: "calendar.badge.clock"
        case .tasks: "checklist"
        case .search: "magnifyingglass"
        case .courses: "books.vertical.fill"
        case .profile: "person.crop.circle.fill"
        }
    }
}

private struct MacSidebar: View {
    let store: PlanoraStore
    @Binding var selection: MacDestination?

    var body: some View {
        List(selection: $selection) {
            Section {
                sidebarLink(.home)
                sidebarLink(.today)
                sidebarLink(.week)
            }

            Section(String(localized: "Learning")) {
                sidebarLink(.tasks)
                sidebarLink(.search)
                sidebarLink(.courses)
            }

            Section(String(localized: "Settings")) {
                sidebarLink(.profile)
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                PlanoraLogoMark(size: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "Planora")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.planoraInk)
                    Text(store.userName.isEmpty ? String(localized: "Learning Space") : store.userName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Text(store.curriculum.badge)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(store.curriculum.tint)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.bar)
        }
    }

    private func sidebarLink(_ destination: MacDestination) -> some View {
        Label(destination.title, systemImage: destination.systemImage)
            .tag(destination)
    }
}

private struct MacDeletedTaskUndoBanner: View {
    let count: Int
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.fill")
                .foregroundStyle(.secondary)
            Text(PlanoraLocalization.format(String(localized: "tasks_deleted_format"), count))
                .font(.subheadline.weight(.semibold))
            Button(String(localized: "Undo"), action: undo)
                .buttonStyle(.borderedProminent)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 16, y: 6)
    }
}
#endif
