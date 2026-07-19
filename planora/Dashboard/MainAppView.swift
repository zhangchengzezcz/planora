import SwiftData
import SwiftUI

struct MainAppView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @State private var isShowingCreateFlow = false
    @State private var lastContentTab: MainTab = .home
    @State private var searchFocusRequestID = 0

    var body: some View {
        TabView(selection: $store.selectedTab) {
            Tab(L("首页", "Home"), systemImage: "house.fill", value: MainTab.home) {
                NavigationStack {
                    HomeDashboardView(store: store) {
                        presentCreateFlow()
                    }
                }
            }

            Tab(L("任务", "Tasks"), systemImage: "checklist", value: MainTab.tasks) {
                NavigationStack {
                    TaskListView(store: store)
                }
            }

            Tab(L("新建", "New"), systemImage: "plus", value: MainTab.create, role: .prominent) {
                NavigationStack {
                    CreateTabPlaceholder()
                }
            }

            Tab(L("搜索", "Search"), systemImage: "magnifyingglass", value: MainTab.search, role: .search) {
                NavigationStack {
                    EventSearchView(
                        store: store,
                        isActive: store.selectedTab == .search && !isShowingCreateFlow,
                        focusRequestID: searchFocusRequestID
                    )
                }
            }

            Tab(L("我的", "Me"), systemImage: "person.fill", value: MainTab.profile) {
                NavigationStack {
                    ProfileView(store: store)
                }
            }
        }
        .tint(Color.planoraDeepGreen)
        .background(PlanoraBackground())
        .onChange(of: store.selectedTab) { oldTab, selectedTab in
            if selectedTab == .create {
                presentCreateFlow()
                store.selectedTab = lastContentTab
            } else {
                if selectedTab == .search, oldTab != .search, !isShowingCreateFlow {
                    searchFocusRequestID += 1
                }
                lastContentTab = selectedTab
            }
        }
        .fullScreenCover(isPresented: $isShowingCreateFlow) {
            NavigationStack {
                CreateTaskView(
                    store: store,
                    onClose: {
                        isShowingCreateFlow = false
                    },
                    onComplete: {
                        isShowingCreateFlow = false
                        store.selectedTab = .home
                        lastContentTab = .home
                    }
                )
            }
        }
        .overlay(alignment: .bottom) {
            if let undo = store.pendingDeletionUndo {
                DeletedTaskUndoBanner(count: undo.count) {
                    restore(undo)
                }
                .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
                .padding(.bottom, 82)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy, value: store.pendingDeletionUndo?.id)
    }

    private func presentCreateFlow() {
        isShowingCreateFlow = true
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

private struct DeletedTaskUndoBanner: View {
    let count: Int
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "trash.fill")
                .foregroundStyle(.secondary)

            Text(LF("tasks_deleted_format", count))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.planoraInk)

            Spacer()

            Button(L("撤销", "Undo"), action: undo)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.planoraBlue)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.planoraGlassStroke, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.12), radius: 16, y: 6)
    }
}

private struct CreateTabPlaceholder: View {
    var body: some View {
        PlanoraBackground()
            .ignoresSafeArea()
    }
}
