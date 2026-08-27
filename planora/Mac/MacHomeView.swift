import SwiftData
import SwiftUI

#if os(macOS)
struct MacHomeView: View {
    let store: PlanoraStore
    let createTask: () -> Void
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]

    var body: some View {
        let snapshot = MacHomeSnapshot(tasks: tasks)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if let focus = snapshot.activeTasks.first {
                    MacFocusSection(task: focus)
                } else {
                    ContentUnavailableView {
                        Label(String(localized: "No Tasks Yet"), systemImage: "checklist")
                    } description: {
                        Text(String(localized: "Tap + to create your first task."))
                    } actions: {
                        Button(String(localized: "New Task"), action: createTask)
                            .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, minHeight: 320, alignment: .center)
                }

                Grid(horizontalSpacing: 14, verticalSpacing: 14) {
                    GridRow {
                        MacSummaryGroup(
                            title: String(localized: "Today"),
                            symbol: "sun.max",
                            value: "\(snapshot.todayCount)",
                            detail: String(localized: "Tasks scheduled or due today")
                        )
                        MacSummaryGroup(
                            title: String(localized: "This Week"),
                            symbol: "calendar",
                            value: "\(snapshot.weekCount)",
                            detail: String(localized: "Tasks planned for the current week")
                        )
                    }
                }

                if !snapshot.activeTasks.isEmpty {
                    GroupBox(String(localized: "Upcoming Tasks")) {
                        VStack(spacing: 0) {
                            ForEach(Array(snapshot.activeTasks.prefix(6).enumerated()), id: \.element.id) { index, task in
                                MacCompactTaskRow(task: task)
                                if index < min(snapshot.activeTasks.count, 6) - 1 { Divider() }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 940, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(store.userName.isEmpty
                 ? String(localized: "Home")
                 : String(
                    format: NSLocalizedString("hello_name_format", bundle: .main, comment: "Home greeting"),
                    locale: PlanoraLocalization.preferredLocale,
                    store.userName
                 ))
                .font(.largeTitle.bold())
            Text(String(localized: "See what needs your attention next."))
                .foregroundStyle(.secondary)
        }
    }
}

private struct MacHomeSnapshot {
    let activeTasks: [PlanoraTask]
    let todayCount: Int
    let weekCount: Int

    init(tasks: [PlanoraTask], now: Date = Date(), calendar: Calendar = .current) {
        activeTasks = tasks
            .filter { !$0.isCompleted && !$0.isArchived }
            .planoraSorted { PlanoraTaskOrdering.areInDashboardOrder($0, $1) }
        todayCount = activeTasks.reduce(into: 0) { count, task in
            if task.plannedDate.map(calendar.isDateInToday) == true ||
                task.deadline.map(calendar.isDateInToday) == true {
                count += 1
            }
        }
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else {
            weekCount = 0
            return
        }
        weekCount = activeTasks.reduce(into: 0) { count, task in
            if task.plannedDate.map(week.contains) == true || task.deadline.map(week.contains) == true {
                count += 1
            }
        }
    }
}

private struct MacFocusSection: View {
    let task: PlanoraTask

    var body: some View {
        GroupBox(String(localized: "Current Focus")) {
            HStack(alignment: .center, spacing: 16) {
                TaskCompletionButton(task: task)
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.title2.weight(.semibold))
                    Text(PlanoraFormat.subjectDisplayName(task.subject)).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(task.priority.title)
                    Text(task.deadline?.formatted(date: .abbreviated, time: .omitted) ?? String(localized: "No deadline"))
                        .foregroundStyle(.secondary)
                }
                .font(.callout)
            }
            .padding(8)
        }
    }
}

private struct MacSummaryGroup: View {
    let title: String
    let symbol: String
    let value: String
    let detail: String

    var body: some View {
        GroupBox {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(value).font(.title.bold()).monospacedDigit()
            }
            .padding(6)
        }
        .frame(maxWidth: .infinity)
    }
}

struct MacCompactTaskRow: View {
    let task: PlanoraTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.type.symbol)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title).lineLimit(1)
                Text(PlanoraFormat.subjectDisplayName(task.subject))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let date = task.plannedDate ?? task.deadline {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}
#endif
