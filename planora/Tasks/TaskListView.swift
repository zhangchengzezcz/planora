import SwiftData
import SwiftUI

struct TaskListView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var taskPendingDeletion: PlanoraTask?
    @State private var isShowingDeleteConfirmation = false

    private var sortedTasks: [PlanoraTask] {
        tasks.sorted(by: sortByCompletionTime)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(L("任务", "Tasks"))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.planoraInk)

                Text(L("按完成时间查看所有任务。", "Review every task by completion time."))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 10)

            if sortedTasks.isEmpty {
                ScrollView(showsIndicators: false) {
                    EmptyTaskListCard()
                        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
                        .padding(.top, 8)
                }
            } else {
                List {
                    ForEach(sortedTasks, id: \.id) { task in
                        NavigationLink {
                            TaskDetailView(store: store, task: task)
                        } label: {
                            TaskListRow(task: task)
                        }
                            .buttonStyle(.plain)
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
                                    try? modelContext.save()
                                    Task { await TaskReminderScheduler.synchronize(task: task) }
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

    private func sortByCompletionTime(_ lhs: PlanoraTask, _ rhs: PlanoraTask) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

        if lhs.importance != rhs.importance {
            return lhs.importance > rhs.importance
        }

        switch (lhs.hasDeadline, rhs.hasDeadline) {
        case (true, true):
            if lhs.deadline != rhs.deadline {
                return (lhs.deadline ?? .distantFuture) < (rhs.deadline ?? .distantFuture)
            }
        case (true, false):
            return true
        case (false, true):
            return false
        case (false, false):
            break
        }

        return lhs.createdDate > rhs.createdDate
    }

    private func delete(_ task: PlanoraTask, scope: RecurrenceEditScope) {
        let targets: [PlanoraTask]
        if let seriesID = task.recurrenceSeriesID {
            let series = tasks.filter { $0.recurrenceSeriesID == seriesID }
            switch scope {
            case .occurrence:
                targets = [task]
            case .future:
                targets = series.filter { $0.recurrenceSequence >= task.recurrenceSequence }
            case .entireSeries:
                targets = series
            }
        } else {
            targets = [task]
        }

        let taskIDs = targets.map(\.id)
        if scope == .occurrence,
           let seriesID = task.recurrenceSeriesID {
            RecurringTaskEngine.excludeOccurrence(
                task,
                from: tasks.filter { $0.recurrenceSeriesID == seriesID }
            )
        }
        if let json = try? TaskBackupCodec.json(for: targets) {
            store.stageDeletedTasks(json: json, count: targets.count)
        }
        AutomaticTaskBackup.save(tasks: tasks)
        if scope == .future,
           let seriesID = task.recurrenceSeriesID {
            RecurringTaskEngine.truncateSeries(
                before: task,
                in: tasks.filter { $0.recurrenceSeriesID == seriesID }
            )
        }
        for target in targets { modelContext.delete(target) }
        try? modelContext.save()
        Task { await TaskReminderScheduler.removeRequests(forTaskIDs: taskIDs) }
        taskPendingDeletion = nil
    }
}

private struct TaskListRow: View {
    let task: PlanoraTask

    var body: some View {
        GlassPanel(padding: 16, cornerRadius: PlanoraTheme.compactCornerRadius) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 14) {
                    Image(systemName: task.type.symbol)
                        .font(.headline)
                        .foregroundStyle(task.type.tint)
                        .frame(width: 42, height: 42)
                        .background(task.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

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

                    if task.tracksProgress {
                        TaskListMetric(label: task.progressState.label, value: task.progressState.valueText, tint: task.type.tint)
                    } else {
                        TaskListMetric(label: L("类型", "Type"), value: task.type.title, tint: task.type.tint)
                    }
                }

                if !task.notes.isEmpty {
                    Text(task.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
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
                .minimumScaleFactor(0.75)
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
