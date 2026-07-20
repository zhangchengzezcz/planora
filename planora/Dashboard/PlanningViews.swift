import SwiftData
import SwiftUI

struct PlanningDestinationStrip: View {
    let store: PlanoraStore

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink {
                TodayPlanningView(store: store)
            } label: {
                PlanningDestinationLabel(
                    title: String(localized: "Today"),
                    subtitle: String(localized: "Work today's plan"),
                    symbol: "sun.max.fill",
                    tint: .planoraAmber
                )
            }

            NavigationLink {
                WeekPlanningView(store: store)
            } label: {
                PlanningDestinationLabel(
                    title: String(localized: "This Week"),
                    subtitle: String(localized: "Review seven days"),
                    symbol: "calendar.badge.clock",
                    tint: .planoraBlue
                )
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PlanningDestinationLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    let tint: Color

    var body: some View {
        GlassPanel(padding: 14, cornerRadius: PlanoraTheme.compactCornerRadius, tint: tint.opacity(0.1), interactive: true) {
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: symbol)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
        }
    }
}

struct TodayPlanningView: View {
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]

    private var today: DateInterval {
        let start = Calendar.current.startOfDay(for: Date())
        return DateInterval(start: start, duration: 86_400)
    }

    private var overdue: [PlanoraTask] {
        tasks.filter {
            !$0.isCompleted && $0.hasDeadline && ($0.deadline ?? .distantFuture) < today.start
        }.sorted(by: planningSort)
    }

    private var dueToday: [PlanoraTask] {
        tasks.filter {
            !$0.isCompleted && $0.deadline.map(today.contains) == true
        }.sorted(by: planningSort)
    }

    private var plannedToday: [PlanoraTask] {
        tasks.filter { task in
            !task.isCompleted
                && task.plannedDate.map(today.contains) == true
                && !dueToday.contains(where: { $0.id == task.id })
        }.sorted(by: planningSort)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PlanningHeader(
                    title: String(localized: "Today"),
                    subtitle: Date().formatted(date: .complete, time: .omitted)
                )

                if overdue.isEmpty && dueToday.isEmpty && plannedToday.isEmpty {
                    PlanningEmptyState(title: String(localized: "Nothing Planned Today"))
                } else {
                    PlanningTaskSection(title: String(localized: "Overdue"), tasks: overdue, store: store, tint: .red)
                    PlanningTaskSection(title: String(localized: "Due Today"), tasks: dueToday, store: store, tint: .planoraAmber)
                    PlanningTaskSection(title: String(localized: "Planned Today"), tasks: plannedToday, store: store, tint: .planoraGreen)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .navigationTitle(String(localized: "Today"))
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }

    private func planningSort(_ lhs: PlanoraTask, _ rhs: PlanoraTask) -> Bool {
        PlanoraTaskOrdering.areInPlanningOrder(
            PlanoraTaskSortKey(task: lhs),
            PlanoraTaskSortKey(task: rhs)
        )
    }
}

struct WeekPlanningView: View {
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]

    private var days: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var incompleteTasks: [PlanoraTask] { tasks.filter { !$0.isCompleted } }

    private var scheduledTaskCount: Int {
        days.reduce(0) { $0 + tasks(on: $1).count }
    }

    private var busiestDay: Date? {
        guard scheduledTaskCount > 0 else { return nil }
        return days.max { tasks(on: $0).count < tasks(on: $1).count }
    }

    private var summaryText: String {
        if let busiestDay {
            return PlanoraLocalization.format(
                String(localized: "busiest_day_format"),
                busiestDay.formatted(.dateTime.weekday(.wide)),
                tasks(on: busiestDay).count
            )
        }

        return incompleteTasks.isEmpty
            ? String(localized: "No tasks this week")
            : String(localized: "No scheduled tasks this week")
    }

    private var unscheduled: [PlanoraTask] {
        incompleteTasks.filter { $0.plannedDate == nil }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PlanningHeader(
                    title: String(localized: "This Week"),
                    subtitle: summaryText
                )

                ForEach(days, id: \.self) { day in
                    let dayTasks = tasks(on: day)
                    if dayTasks.isEmpty {
                        WeekDayEmptyState(day: day)
                    } else {
                        DashboardSection(title: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
                            VStack(spacing: 10) {
                                ForEach(dayTasks, id: \.id) { task in
                                    PlanningTaskRow(store: store, task: task, tint: task.type.tint)
                                }
                            }
                        }
                    }
                }

                PlanningTaskSection(
                    title: PlanoraLocalization.format(String(localized: "unscheduled_tasks_format"), unscheduled.count),
                    tasks: unscheduled,
                    store: store,
                    tint: .gray
                )
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .navigationTitle(String(localized: "This Week"))
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }

    private func tasks(on day: Date) -> [PlanoraTask] {
        let calendar = Calendar.current
        return incompleteTasks.filter { task in
            if let plannedDate = task.plannedDate {
                return calendar.isDate(plannedDate, inSameDayAs: day)
            }
            return task.deadline.map { calendar.isDate($0, inSameDayAs: day) } == true
        }
    }
}

private struct WeekDayEmptyState: View {
    let day: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                .font(.headline)
                .foregroundStyle(Color.planoraInk)

            Text(String(localized: "No tasks"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}

private struct PlanningHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.planoraInk)
            Text(subtitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct PlanningTaskSection: View {
    let title: String
    let tasks: [PlanoraTask]
    let store: PlanoraStore
    let tint: Color

    var body: some View {
        if !tasks.isEmpty {
            DashboardSection(title: title) {
                VStack(spacing: 10) {
                    ForEach(tasks, id: \.id) { task in
                        PlanningTaskRow(store: store, task: task, tint: tint)
                    }
                }
            }
        }
    }
}

private struct PlanningTaskRow: View {
    let store: PlanoraStore
    let task: PlanoraTask
    let tint: Color

    var body: some View {
        NavigationLink {
            TaskDetailView(store: store, task: task)
        } label: {
            HStack(spacing: 12) {
                TaskCompletionButton(task: task)

                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.planoraInk)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Text(PlanoraFormat.subjectDisplayName(task.subject))
                        if task.isRecurring {
                            Image(systemName: "repeat")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
                PriorityPill(priority: task.priority)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct PlanningEmptyState: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.planoraInk)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
