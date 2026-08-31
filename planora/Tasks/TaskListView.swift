import SwiftData
import SwiftUI

struct TaskListView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @Environment(\.planoraTaskDisplay) private var displaySettings
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var taskPendingDeletion: PlanoraTask?
    @State private var isShowingDeleteConfirmation = false
    @State private var selectedTask: PlanoraTask?
    @State private var isSelecting = false
    @State private var selectedTaskIDs = Set<UUID>()
    @State private var isShowingBulkActions = false
    @State private var statusFilter = PlanoraTaskListStatus.active

    var body: some View {
        let visibleTasks = PlanoraTaskListProjection.tasks(
            from: tasks,
            settings: displaySettings,
            status: statusFilter
        )

        Group {
            if visibleTasks.isEmpty {
                ScrollView(showsIndicators: false) {
                    EmptyTaskListCard()
                        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
                        .padding(.top, 8)
                }
            } else {
                List {
                    ForEach(visibleTasks, id: \.id) { task in
                        HStack(spacing: 10) {
                            if isSelecting {
                                Image(systemName: selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(selectedTaskIDs.contains(task.id) ? Color.accentColor : Color.secondary)
                                    .accessibilityHidden(true)
                            }

                            TaskListRow(task: task)
                        }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if isSelecting {
                                    toggleSelection(task)
                                } else {
                                    selectedTask = task
                                }
                            }
                            .contextMenu {
                                if task.isDeleted {
                                    Button(String(localized: "Restore Task"), systemImage: "arrow.uturn.backward") {
                                        PlanoraTaskOperations.restoreFromRecentlyDeleted([task], modelContext: modelContext)
                                    }
                                    Button(String(localized: "Delete Permanently"), systemImage: "trash", role: .destructive) {
                                        PlanoraTaskOperations.permanentlyDelete([task], allTasks: tasks, modelContext: modelContext)
                                    }
                                } else {
                                Button(
                                    task.isPinned ? String(localized: "Unpin Task") : String(localized: "Pin Task"),
                                    systemImage: task.isPinned ? "pin.slash" : "pin"
                                ) {
                                    togglePinned(task)
                                }
                                }
                            }
                            .accessibilityHint(isSelecting ? String(localized: "Select or deselect this task") : String(localized: "Open task details"))
                            .listRowInsets(EdgeInsets(top: 7, leading: PlanoraTheme.pageHorizontalPadding, bottom: 7, trailing: PlanoraTheme.pageHorizontalPadding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                if !isSelecting {
                                    Button(role: .destructive) {
                                        if task.isDeleted {
                                            PlanoraTaskOperations.permanentlyDelete([task], allTasks: tasks, modelContext: modelContext)
                                        } else {
                                            taskPendingDeletion = task
                                            isShowingDeleteConfirmation = true
                                        }
                                    } label: {
                                        Label(task.isDeleted ? String(localized: "Delete Permanently") : String(localized: "Delete"), systemImage: "trash.fill")
                                    }
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if !isSelecting {
                                    Button {
                                        if task.isDeleted {
                                            PlanoraTaskOperations.restoreFromRecentlyDeleted([task], modelContext: modelContext)
                                        } else {
                                            task.setCompleted(!task.isCompleted)
                                            PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                                        }
                                    } label: {
                                        Label(
                                            task.isDeleted ? String(localized: "Restore Task") : (task.isCompleted ? String(localized: "Mark Incomplete") : String(localized: "Mark Complete")),
                                            systemImage: task.isDeleted ? "arrow.uturn.backward" : (task.isCompleted ? "arrow.uturn.backward" : "checkmark")
                                        )
                                    }
                                    .tint(task.isDeleted || task.isCompleted ? .orange : .planoraGreen)
                                }
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .safeAreaBar(edge: .top, spacing: 0) {
            taskListHeader
        }
        .safeAreaBar(edge: .bottom, spacing: 0) {
            if isSelecting {
                HStack(spacing: 12) {
                    Text(PlanoraLocalization.format(String(localized: "selected_tasks_format"), selectedTaskIDs.count))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button(String(localized: "Actions"), systemImage: "ellipsis.circle") {
                        isShowingBulkActions = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedTaskIDs.isEmpty)
                }
                .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
                .padding(.vertical, 10)
            }
        }
        .scrollEdgeEffectStyle(.automatic, for: .top)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(store: store, task: task)
        }
        .alert(String(localized: "Delete Task?"), isPresented: $isShowingDeleteConfirmation, presenting: taskPendingDeletion) { task in
            if task.isRecurring {
                Button(String(localized: "Delete This Occurrence"), role: .destructive) {
                    delete(task, scope: .occurrence)
                }
                Button(String(localized: "Delete This and Future"), role: .destructive) {
                    delete(task, scope: .future)
                }
                Button(String(localized: "Delete Entire Series"), role: .destructive) {
                    delete(task, scope: .entireSeries)
                }
            } else {
                Button(String(localized: "Delete"), role: .destructive) {
                    delete(task, scope: .occurrence)
                }
            }

            Button(String(localized: "Cancel"), role: .cancel) {
                taskPendingDeletion = nil
            }
        } message: { task in
            Text(PlanoraLocalization.format(String(localized: "delete_task_confirmation_format"), task.title))
        }
        .sheet(isPresented: $isShowingBulkActions) {
            BulkTaskActionsView(
                store: store,
                selectedTasks: tasks.filter { selectedTaskIDs.contains($0.id) },
                allTasks: tasks,
                onFinish: finishSelection
            )
        }
    }

    private var taskListHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Tasks"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(String(localized: "Tasks are displayed and sorted using your settings."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
                if statusFilter != .deleted {
                    Button(isSelecting ? String(localized: "Done") : String(localized: "Select")) {
                        if isSelecting {
                            finishSelection()
                        } else {
                            isSelecting = true
                        }
                    }
                    .buttonStyle(.bordered)
                }
                ProfileAvatarLink(store: store)
            }

            Picker(String(localized: "Status"), selection: $statusFilter) {
                ForEach(PlanoraTaskListStatus.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .onChange(of: statusFilter) { _, _ in finishSelection() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private func delete(_ task: PlanoraTask, scope: RecurrenceEditScope) {
        PlanoraTaskOperations.delete(
            task,
            scope: scope,
            allTasks: tasks,
            modelContext: modelContext,
            store: store
        )
        taskPendingDeletion = nil
    }

    private func togglePinned(_ task: PlanoraTask) {
        task.isPinned.toggle()
        PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
    }

    private func toggleSelection(_ task: PlanoraTask) {
        if selectedTaskIDs.contains(task.id) {
            selectedTaskIDs.remove(task.id)
        } else {
            selectedTaskIDs.insert(task.id)
        }
    }

    private func finishSelection() {
        selectedTaskIDs.removeAll()
        isSelecting = false
        isShowingBulkActions = false
    }
}

enum PlanoraTaskListStatus: String, CaseIterable, Identifiable {
    case active
    case completed
    case archived
    case pinned
    case deleted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active: String(localized: "Active")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Archived")
        case .pinned: String(localized: "Pinned")
        case .deleted: String(localized: "Recently Deleted")
        }
    }
}

enum PlanoraTaskListProjection {
    static func tasks(
        from tasks: [PlanoraTask],
        settings: PlanoraTaskDisplaySettings,
        status: PlanoraTaskListStatus = .active
    ) -> [PlanoraTask] {
        let visibleTasks = tasks.filter { task in
            switch status {
            case .active:
                return !task.isCompleted && !task.isArchived && !task.isDeleted
            case .completed:
                return task.isCompleted && !task.isArchived && !task.isDeleted
            case .archived:
                return task.isArchived && !task.isDeleted
            case .pinned:
                return task.isPinned && !task.isArchived && !task.isDeleted && (settings.showsCompletedTasks || !task.isCompleted)
            case .deleted:
                return task.isDeleted
            }
        }

        return visibleTasks.planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInListOrder(lhs, rhs, sortOrder: settings.sortOrder)
        }
    }
}

private struct TaskListRow: View {
    @Environment(\.planoraTaskDisplay) private var displaySettings
    let task: PlanoraTask

    private var isCompact: Bool { displaySettings.density == .compact }

    var body: some View {
        GlassPanel(padding: isCompact ? 12 : 16, cornerRadius: PlanoraTheme.compactCornerRadius) {
            VStack(alignment: .leading, spacing: isCompact ? 9 : 13) {
                HStack(spacing: isCompact ? 10 : 14) {
                    Image(systemName: task.type.symbol)
                        .font(.headline)
                        .foregroundStyle(task.type.tint)
                        .frame(width: isCompact ? 34 : 42, height: isCompact ? 34 : 42)
                        .background(task.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: isCompact ? 10 : 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 5) {
                            Text(task.title)
                                .font(.headline)
                                .foregroundStyle(Color.planoraInk)
                                .lineLimit(1)
                                .minimumScaleFactor(0.78)

                            if task.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(task.type.tint)
                                    .accessibilityLabel(String(localized: "Pinned Tasks"))
                            }
                        }

                        Text(task.subject.planoraTaskListSubjectName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 10)

                    VStack(alignment: .trailing, spacing: 6) {
                        MiniStatusPill(title: task.type.title, tint: task.type.tint)
                        PriorityPill(priority: task.priority)
                    }
                }

                HStack(spacing: 10) {
                    TaskListMetric(label: String(localized: "Completion Time"), value: task.completionTimeText, tint: task.type.tint, isPrimary: true)

                    if task.tracksProgress && (task.progressState.kind != .percentage || displaySettings.showsProgressPercentage) {
                        TaskListMetric(label: task.progressState.label, value: task.progressState.valueText, tint: task.type.tint)
                    } else {
                        TaskListMetric(label: String(localized: "Type"), value: task.type.title, tint: task.type.tint)
                    }
                }

                if displaySettings.showsNotes && !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: PlanoraTheme.compactCornerRadius, style: .continuous))
        .opacity(task.isCompleted ? 0.62 : 1)
    }
}

private struct TaskListMetric: View {
    let label: String
    let value: String
    let tint: Color
    var isPrimary = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isPrimary ? Color.planoraInk : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

private struct EmptyTaskListCard: View {
    var body: some View {
        GlassPanel {
            VStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title.weight(.bold))
                    .foregroundStyle(LinearGradient.planoraAccent)

                Text(String(localized: "No Tasks Yet"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(String(localized: "After you create tasks, they will appear here by completion time."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 190, alignment: .center)
        }
    }
}

private extension PlanoraTask {
    var completionTimeText: String {
        guard hasDeadline, let deadline else {
            return String(localized: "No deadline")
        }

        return PlanoraFormat.monthDay(deadline)
    }
}

private extension String {
    var planoraTaskListSubjectName: String {
        PlanoraFormat.subjectDisplayName(self)
    }
}
