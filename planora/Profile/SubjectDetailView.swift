import SwiftData
import SwiftUI

struct SubjectDetailView: View {
    let store: PlanoraStore
    let subject: String

    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]

    private var subjectTasks: [PlanoraTask] {
        tasks.filter { $0.subject == subject }
    }

    private var sortedTasks: [PlanoraTask] {
        subjectTasks.planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInSubjectDetailOrder(lhs, rhs)
        }
    }

    private var upcomingTasks: [PlanoraTask] {
        Array(sortedTasks.filter { !$0.isCompleted && $0.hasDeadline }.prefix(4))
    }

    private var completedCount: Int {
        subjectTasks.filter(\.isCompleted).count
    }

    private var openCount: Int {
        subjectTasks.count - completedCount
    }

    private var completionRate: Double {
        guard !subjectTasks.isEmpty else { return 0 }
        return Double(completedCount) / Double(subjectTasks.count)
    }

    private var learningProgress: Double {
        let trackedTasks = subjectTasks.filter(\.tracksProgress)
        guard !trackedTasks.isEmpty else { return completionRate }
        return trackedTasks.map(\.progressFraction).reduce(0, +) / Double(trackedTasks.count)
    }

    private var tint: Color {
        sortedTasks.first?.type.tint ?? store.curriculum.tint
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                header
                overviewSection

                if !upcomingTasks.isEmpty {
                    taskSection(title: L("即将到来", "Upcoming"), tasks: upcomingTasks)
                }

                if sortedTasks.isEmpty {
                    emptyState
                } else {
                    taskSection(title: L("全部任务", "All Tasks"), tasks: sortedTasks)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "book.closed.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 52, height: 52)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(PlanoraFormat.subjectDisplayName(subject))
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color.planoraInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.72)

                    Text(L("科目学习空间", "Subject Workspace"))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var overviewSection: some View {
        DashboardSection(title: L("学习概览", "Learning Overview")) {
            VStack(spacing: 18) {
                HStack(spacing: 12) {
                    SubjectMetric(label: L("任务", "Tasks"), value: "\(subjectTasks.count)", tint: tint)
                    SubjectMetric(label: L("进行中", "Open"), value: "\(openCount)", tint: .planoraAmber)
                    SubjectMetric(label: L("已完成", "Completed"), value: "\(completedCount)", tint: .planoraGreen)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L("学习进度", "Learning Progress"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.planoraInk)

                        Spacer()

                        Text(PlanoraFormat.percent(learningProgress))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(tint)
                    }

                    ProgressView(value: learningProgress)
                        .tint(tint)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(L("任务完成率", "Task Completion Rate"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.planoraInk)

                        Spacer()

                        Text(PlanoraFormat.percent(completionRate))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.planoraGreen)
                    }

                    ProgressView(value: completionRate)
                        .tint(Color.planoraGreen)
                }
            }
            .padding(18)
        }
    }

    private func taskSection(title: String, tasks: [PlanoraTask]) -> some View {
        DashboardSection(title: title) {
            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    NavigationLink {
                        TaskDetailView(store: store, task: task)
                    } label: {
                        SubjectTaskRow(task: task)
                    }
                    .buttonStyle(.plain)

                    if index != tasks.indices.last {
                        Divider().padding(.leading, 58)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        GlassPanel {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: "tray")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("这个科目还没有任务", "No Tasks for This Subject"))
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Text(L("为这个科目创建任务后，它会显示在这里。", "Create a task for this subject and it will appear here."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

}

private struct SubjectMetric: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SubjectTaskRow: View {
    let task: PlanoraTask

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : task.type.symbol)
                .font(.headline)
                .foregroundStyle(task.isCompleted ? Color.planoraGreen : task.type.tint)
                .frame(width: 42, height: 42)
                .background(task.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 5) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                HStack(spacing: 7) {
                    Text(task.type.title)

                    Text("·")

                    Text(deadlineText)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 8)

            if task.tracksProgress {
                Text(PlanoraFormat.percent(task.progressFraction))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(task.type.tint)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .contentShape(Rectangle())
        .opacity(task.isCompleted ? 0.64 : 1)
    }

    private var deadlineText: String {
        guard task.hasDeadline, let deadline = task.deadline else {
            return L("无截止日期", "No deadline")
        }

        return PlanoraFormat.monthDay(deadline)
    }
}
