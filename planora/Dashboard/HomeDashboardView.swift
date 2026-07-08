import SwiftData
import SwiftUI

struct HomeDashboardView: View {
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]

    private var activeTasks: [PlanoraTask] {
        sortedTasks.filter { !$0.isCompleted }
    }

    private var sortedTasks: [PlanoraTask] {
        tasks.sorted { lhs, rhs in
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

            if lhs.importance != rhs.importance {
                return lhs.importance > rhs.importance
            }

            return lhs.createdDate < rhs.createdDate
        }
    }

    private var focusTask: PlanoraTask? {
        activeTasks.first ?? sortedTasks.first
    }

    private var upcomingTasks: [PlanoraTask] {
        Array(activeTasks.prefix(6))
    }

    private var taskCompletionSnapshot: TaskCompletionSnapshot {
        TaskCompletionSnapshot(
            title: "This week",
            completed: tasks.filter(\.isCompleted).count,
            total: tasks.count,
            tint: .planoraGreen
        )
    }

    private var subjectProgressSnapshots: [SubjectProgressSnapshot] {
        let grouped = Dictionary(grouping: tasks.compactMap { task -> (String, Double, Color)? in
            guard let progress = task.progressState.percentageValue else { return nil }
            return (task.subject, progress, task.type.tint)
        }, by: \.0)

        return grouped
            .map { subject, values in
                let average = values.map(\.1).reduce(0, +) / Double(values.count)
                let tint = values.first?.2 ?? .planoraBlue
                return SubjectProgressSnapshot(title: subject, value: average, tint: tint)
            }
            .sorted { $0.title < $1.title }
    }

    private var calendarEvents: [CalendarEvent] {
        let calendar = Calendar.current

        return sortedTasks.compactMap { task -> CalendarEvent? in
            guard task.hasDeadline, let deadline = task.deadline else { return nil }
            guard calendar.isDate(deadline, equalTo: calendarMonthDate, toGranularity: .month) else { return nil }

            return CalendarEvent(
                day: calendar.component(.day, from: deadline),
                title: task.title,
                tint: task.type.tint
            )
        }
    }

    private var calendarMonthDate: Date {
        sortedTasks.first(where: { $0.hasDeadline })?.deadline ?? Date()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HomeHeader(store: store)

                if let focusTask {
                    TodayFocusCard(task: focusTask)

                    DashboardSection(title: "Upcoming Tasks") {
                        VStack(spacing: 0) {
                            ForEach(Array(upcomingTasks.enumerated()), id: \.element.id) { index, task in
                                TaskRow(task: task)

                                if index != upcomingTasks.indices.last {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                    }
                } else {
                    EmptyTasksCard()
                }

                if !tasks.isEmpty {
                    DashboardSection(title: "Learning Progress") {
                        VStack(alignment: .leading, spacing: 18) {
                            if !subjectProgressSnapshots.isEmpty {
                                ProgressGroupTitle("Subject Progress")

                                ForEach(subjectProgressSnapshots) { snapshot in
                                    ProgressSubjectRow(title: snapshot.title, value: snapshot.value, tint: snapshot.tint)
                                }

                                Divider()
                            }

                            ProgressGroupTitle("Task Completion")
                            TaskCompletionRow(snapshot: taskCompletionSnapshot)
                        }
                        .padding(20)
                    }
                }

                if !calendarEvents.isEmpty {
                    DashboardSection(title: "Calendar Preview") {
                        CalendarPreview(events: calendarEvents, monthDate: calendarMonthDate)
                            .padding(18)
                    }
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
    }
}

private struct HomeHeader: View {
    let store: PlanoraStore

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Hello \(store.userName)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.planoraInk)

                Text("What should I focus on now?")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Menu {
                ForEach(Curriculum.allCases) { curriculum in
                    Button {
                        store.selectCurriculum(curriculum)
                    } label: {
                        Label(curriculum.title, systemImage: curriculum.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(store.curriculum.badge)
                        .font(.subheadline.weight(.bold))

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(store.curriculum.tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.16), in: Capsule())
                .glassEffect(.regular.tint(store.curriculum.tint.opacity(0.12)).interactive(), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TodayFocusCard: View {
    let task: PlanoraTask

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Now")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.planoraBlue)
                            .textCase(.uppercase)

                        Text(task.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.planoraInk)

                        Text(task.subject)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "target")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.planoraBlue)
                        .frame(width: 48, height: 48)
                        .background(Color.planoraBlue.opacity(0.12), in: Circle())
                }

                Text(focusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TaskStatusGrid(task: task)

                if let progress = task.progressState.percentageValue {
                    ProgressView(value: progress)
                        .tint(task.type.tint)
                }
            }
        }
    }

    private var focusText: String {
        guard task.hasDeadline, let deadline = task.deadline else {
            return "No deadline. Complete your next milestone."
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: deadline)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        if days < 0 {
            return "Overdue. Complete your next milestone."
        }

        if days == 0 {
            return "Due today. Complete your next milestone."
        }

        return "\(days) days left. Complete your next milestone."
    }
}

private struct TaskRow: View {
    let task: PlanoraTask

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                        .font(.headline)
                        .foregroundStyle(task.type.tint)
                        .frame(width: 42, height: 42)
                    .background(task.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Text(task.subject)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            TaskStatusGrid(task: task)

            if let progress = task.progressState.percentageValue {
                ProgressView(value: progress)
                    .tint(task.type.tint)
            }
        }
        .padding(18)
    }
}

private struct TaskStatusGrid: View {
    let task: PlanoraTask

    var body: some View {
        HStack(spacing: 10) {
            TaskStatusTile(label: "Deadline", value: deadlineText, tint: task.type.tint)
            TaskStatusTile(label: task.progressState.label, value: task.progressState.valueText, tint: task.type.tint)
        }
    }

    private var deadlineText: String {
        guard task.hasDeadline, let deadline = task.deadline else {
            return "No deadline"
        }

        return deadline.formatted(.dateTime.month(.abbreviated).day())
    }
}

private struct TaskStatusTile: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(label == "Deadline" ? Color.planoraInk : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct ProgressGroupTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct EmptyTasksCard: View {
    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "plus.circle.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(LinearGradient.planoraAccent)

                Text("No tasks yet")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text("Start planning your learning journey.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("Tap + to create your first task.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.planoraDeepGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TaskCompletionRow: View {
    let snapshot: TaskCompletionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)

                Spacer()

                Text(snapshot.valueText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(snapshot.tint)
            }

            ProgressView(value: snapshot.value)
                .tint(snapshot.tint)
        }
    }
}

private struct CalendarPreview: View {
    let events: [CalendarEvent]
    let monthDate: Date

    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var eventDays: Set<Int> {
        Set(events.map(\.day))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(monthDate.formatted(.dateTime.month(.wide)))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Spacer()

                Text("\(events.count) events")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(Array(weekdays.enumerated()), id: \.offset) { _, weekday in
                    Text(weekday)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(calendarDays, id: \.id) { item in
                    let day = item.value

                    ZStack(alignment: .bottom) {
                        Text("\(day)")
                            .font(.caption.weight(eventDays.contains(day) ? .bold : .medium))
                            .foregroundStyle(eventDays.contains(day) ? Color.planoraInk : .secondary)
                            .frame(width: 34, height: 34)
                            .background {
                                if eventDays.contains(day) {
                                    Circle().fill(Color.planoraBlue.opacity(0.14))
                                }
                            }

                        if eventDays.contains(day) {
                            Circle()
                                .fill(Color.planoraBlue)
                                .frame(width: 4, height: 4)
                                .offset(y: -3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var calendarDays: [CalendarDay] {
        let range = Calendar.current.range(of: .day, in: .month, for: monthDate) ?? 1..<31
        return range.map(CalendarDay.init(value:))
    }
}

private struct CalendarDay: Identifiable {
    let value: Int
    var id: String { "day-\(value)" }
}
