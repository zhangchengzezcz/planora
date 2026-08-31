import SwiftData
import SwiftUI

#if os(macOS)
enum MacPlanningMode { case today, week }

struct MacPlanningView: View {
    let store: PlanoraStore
    let mode: MacPlanningMode
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]

    private var activeTasks: [PlanoraTask] { tasks.filter { !$0.isCompleted && !$0.isArchived && !$0.isDeleted } }

    var body: some View {
        List {
            if mode == .today {
                todaySections
            } else {
                weekSections
            }
        }
        .listStyle(.inset)
        .overlay {
            if visibleTaskCount == 0 {
                ContentUnavailableView(
                    mode == .today ? String(localized: "Nothing Planned Today") : String(localized: "No tasks this week"),
                    systemImage: mode == .today ? "sun.max" : "calendar"
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder private var todaySections: some View {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let overdue = activeTasks.filter { $0.hasDeadline && ($0.deadline ?? .distantFuture) < start }
        let due = activeTasks.filter { $0.deadline.map(calendar.isDateInToday) == true }
        let planned = activeTasks.filter { $0.plannedDate.map(calendar.isDateInToday) == true && $0.deadline.map(calendar.isDateInToday) != true }
        MacTaskSection(title: String(localized: "Overdue"), tasks: overdue)
        MacTaskSection(title: String(localized: "Due Today"), tasks: due)
        MacTaskSection(title: String(localized: "Planned Today"), tasks: planned)
    }

    @ViewBuilder private var weekSections: some View {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        ForEach(0..<7, id: \.self) { offset in
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                let dayTasks = activeTasks.filter {
                    ($0.plannedDate ?? $0.deadline).map { calendar.isDate($0, inSameDayAs: day) } == true
                }
                MacTaskSection(title: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()), tasks: dayTasks)
            }
        }
    }

    private var visibleTaskCount: Int {
        let calendar = Calendar.current
        if mode == .today {
            let start = calendar.startOfDay(for: Date())
            return activeTasks.filter {
                ($0.hasDeadline && ($0.deadline ?? .distantFuture) < start)
                || $0.deadline.map(calendar.isDateInToday) == true
                || $0.plannedDate.map(calendar.isDateInToday) == true
            }.count
        }
        guard let week = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return 0 }
        return activeTasks.filter { task in
            [task.plannedDate, task.deadline].compactMap { $0 }.contains(where: week.contains)
        }.count
    }
}

private struct MacTaskSection: View {
    let title: String
    let tasks: [PlanoraTask]

    var body: some View {
        if !tasks.isEmpty {
            Section(title) {
                ForEach(tasks) { task in
                    HStack(spacing: 10) {
                        TaskCompletionButton(task: task)
                        MacCompactTaskRow(task: task)
                    }
                }
            }
        }
    }
}
#endif
