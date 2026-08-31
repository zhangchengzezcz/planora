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

    var body: some View {
        let snapshot = TodayPlanningSnapshot(tasks: tasks)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PlanningHeader(
                    title: String(localized: "Today"),
                    subtitle: snapshot.titleDate.formatted(date: .complete, time: .omitted)
                )

                if snapshot.isEmpty {
                    PlanningEmptyState(title: String(localized: "Nothing Planned Today"))
                } else {
                    PlanningTaskSection(title: String(localized: "Overdue"), tasks: snapshot.overdue, store: store, tint: .red)
                    PlanningTaskSection(title: String(localized: "Due Today"), tasks: snapshot.dueToday, store: store, tint: .planoraAmber)
                    PlanningTaskSection(title: String(localized: "Planned Today"), tasks: snapshot.plannedToday, store: store, tint: .planoraGreen)
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
}

struct WeekPlanningView: View {
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]

    var body: some View {
        let snapshot = WeekPlanningSnapshot(tasks: tasks)

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PlanningHeader(
                    title: String(localized: "This Week"),
                    subtitle: snapshot.summaryText
                )

                ForEach(snapshot.days, id: \.self) { day in
                    let dayTasks = snapshot.tasks(on: day)
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
                    title: PlanoraLocalization.format(String(localized: "unscheduled_tasks_format"), snapshot.unscheduled.count),
                    tasks: snapshot.unscheduled,
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
}

private struct TodayPlanningSnapshot {
    let titleDate: Date
    let overdue: [PlanoraTask]
    let dueToday: [PlanoraTask]
    let plannedToday: [PlanoraTask]

    var isEmpty: Bool {
        overdue.isEmpty && dueToday.isEmpty && plannedToday.isEmpty
    }

    init(tasks: [PlanoraTask], now: Date = Date(), calendar: Calendar = .current) {
        titleDate = now
        let start = calendar.startOfDay(for: now)
        let interval = DateInterval(start: start, duration: 86_400)
        var overdue: [PlanoraTask] = []
        var dueToday: [PlanoraTask] = []
        var plannedToday: [PlanoraTask] = []

        for task in tasks where !task.isCompleted && !task.isArchived && !task.isDeleted {
            if task.hasDeadline, let deadline = task.deadline, deadline < start {
                overdue.append(task)
            }

            if task.deadline.map(interval.contains) == true {
                dueToday.append(task)
            } else if task.plannedDate.map(interval.contains) == true {
                plannedToday.append(task)
            }
        }

        self.overdue = PlanoraPlanningSorter.sorted(overdue)
        self.dueToday = PlanoraPlanningSorter.sorted(dueToday)
        self.plannedToday = PlanoraPlanningSorter.sorted(plannedToday)
    }
}

private struct WeekPlanningSnapshot {
    let days: [Date]
    let unscheduled: [PlanoraTask]
    let summaryText: String

    private let tasksByDay: [Date: [PlanoraTask]]

    init(tasks: [PlanoraTask], now: Date = Date(), calendar: Calendar = .current) {
        let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? calendar.startOfDay(for: now)
        let days = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        let weekDays = Set(days.map { calendar.startOfDay(for: $0) })
        var tasksByDay: [Date: [PlanoraTask]] = [:]
        var unscheduled: [PlanoraTask] = []
        var incompleteCount = 0

        for task in tasks where !task.isCompleted && !task.isArchived && !task.isDeleted {
            incompleteCount += 1
            if task.plannedDate == nil {
                unscheduled.append(task)
            }

            let schedulingDate = task.plannedDate ?? task.deadline
            guard let schedulingDate else { continue }
            let day = calendar.startOfDay(for: schedulingDate)
            guard weekDays.contains(day) else { continue }
            tasksByDay[day, default: []].append(task)
        }

        for day in tasksByDay.keys {
            tasksByDay[day] = PlanoraPlanningSorter.sorted(tasksByDay[day] ?? [])
        }

        self.days = days
        self.unscheduled = unscheduled
        self.tasksByDay = tasksByDay

        if let busiestDay = days.max(by: { (tasksByDay[$0]?.count ?? 0) < (tasksByDay[$1]?.count ?? 0) }),
           let busiestCount = tasksByDay[busiestDay]?.count,
           busiestCount > 0 {
            summaryText = PlanoraLocalization.format(
                String(localized: "busiest_day_format"),
                busiestDay.formatted(.dateTime.weekday(.wide)),
                busiestCount
            )
        } else {
            summaryText = incompleteCount == 0
                ? String(localized: "No tasks this week")
                : String(localized: "No scheduled tasks this week")
        }
    }

    func tasks(on day: Date) -> [PlanoraTask] {
        tasksByDay[Calendar.current.startOfDay(for: day)] ?? []
    }
}

private enum PlanoraPlanningSorter {
    static func sorted(_ tasks: [PlanoraTask]) -> [PlanoraTask] {
        tasks.planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInPlanningOrder(lhs, rhs)
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
