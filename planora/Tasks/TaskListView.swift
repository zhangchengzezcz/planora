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

    var body: some View {
        let visibleTasks = PlanoraTaskListProjection.tasks(
            from: tasks,
            settings: displaySettings
        )

        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("任务", "Tasks"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(L("根据设置显示和排序任务。", "Tasks are displayed and sorted using your settings."))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if visibleTasks.isEmpty {
                ScrollView(showsIndicators: false) {
                    EmptyTaskListCard()
                        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
                        .padding(.top, 8)
                }
            } else {
                List {
                    ForEach(visibleTasks, id: \.id) { task in
                        Button {
                            selectedTask = task
                        } label: {
                            TaskListRow(task: task)
                        }
                            .buttonStyle(.plain)
                            .accessibilityHint(L("打开任务详情", "Open task details"))
                            .listRowInsets(EdgeInsets(top: 7, leading: PlanoraTheme.pageHorizontalPadding, bottom: 7, trailing: PlanoraTheme.pageHorizontalPadding))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    taskPendingDeletion = task
                                    isShowingDeleteConfirmation = true
                                } label: {
                                    Label(L("删除", "Delete"), systemImage: "trash.fill")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                Button {
                                    task.setCompleted(!task.isCompleted)
                                    PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                                } label: {
                                    Label(
                                        task.isCompleted ? L("标记为未完成", "Mark Incomplete") : L("标记为完成", "Mark Complete"),
                                        systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark"
                                    )
                                }
                                .tint(task.isCompleted ? .orange : .planoraGreen)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
        .navigationDestination(item: $selectedTask) { task in
            TaskDetailView(store: store, task: task)
        }
        .alert(L("删除任务？", "Delete Task?"), isPresented: $isShowingDeleteConfirmation, presenting: taskPendingDeletion) { task in
            if task.isRecurring {
                Button(L("仅删除本次", "Delete This Occurrence"), role: .destructive) {
                    delete(task, scope: .occurrence)
                }
                Button(L("删除本次及以后", "Delete This and Future"), role: .destructive) {
                    delete(task, scope: .future)
                }
                Button(L("删除整个系列", "Delete Entire Series"), role: .destructive) {
                    delete(task, scope: .entireSeries)
                }
            } else {
                Button(L("删除", "Delete"), role: .destructive) {
                    delete(task, scope: .occurrence)
                }
            }

            Button(L("取消", "Cancel"), role: .cancel) {
                taskPendingDeletion = nil
            }
        } message: { task in
            Text(LF("delete_task_confirmation_format", task.title))
        }
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
}

enum PlanoraTaskListProjection {
    static func tasks(
        from tasks: [PlanoraTask],
        settings: PlanoraTaskDisplaySettings
    ) -> [PlanoraTask] {
        tasks
            .filter { settings.showsCompletedTasks || !$0.isCompleted }
            .planoraSorted { lhs, rhs in
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
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(Color.planoraInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

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
                    TaskListMetric(label: L("完成时间", "Completion Time"), value: task.completionTimeText, tint: task.type.tint, isPrimary: true)

                    if task.tracksProgress && (task.progressState.kind != .percentage || displaySettings.showsProgressPercentage) {
                        TaskListMetric(label: task.progressState.label, value: task.progressState.valueText, tint: task.type.tint)
                    } else {
                        TaskListMetric(label: L("类型", "Type"), value: task.type.title, tint: task.type.tint)
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
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "checklist")
                    .font(.title.weight(.bold))
                    .foregroundStyle(LinearGradient.planoraAccent)

                Text(L("还没有任务", "No Tasks Yet"))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(L("创建任务后，这里会按完成时间显示所有任务。", "After you create tasks, they will appear here by completion time."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private extension PlanoraTask {
    var completionTimeText: String {
        guard hasDeadline, let deadline else {
            return L("无截止日期", "No deadline")
        }

        return PlanoraFormat.monthDay(deadline)
    }
}

private extension String {
    var planoraTaskListSubjectName: String {
        PlanoraFormat.subjectDisplayName(self)
    }
}
