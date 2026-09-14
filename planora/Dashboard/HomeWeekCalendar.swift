import SwiftUI

struct HomeWeekCalendar: View {
    let store: PlanoraStore
    let tasks: [PlanoraTask]
    @Binding var selectedDate: Date
    @State private var showsDatePicker = false

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = 2
        return calendar
    }

    private var days: [Date] {
        HomeWeekCalendarSchedule.days(containing: selectedDate, calendar: calendar)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Button { moveWeek(-1) } label: { Image(systemName: "chevron.left") }
                    .help(String(localized: "Previous Week"))
                    .accessibilityLabel(String(localized: "Previous Week"))
                Button { showsDatePicker = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                        if let first = days.first, let last = days.last {
                            Text(first, format: .dateTime.month(.twoDigits).day(.twoDigits))
                            Text("–")
                            Text(last, format: .dateTime.month(.twoDigits).day(.twoDigits))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                }
                .popover(isPresented: $showsDatePicker) {
                    VStack(spacing: 12) {
                        DatePicker("Date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        Button("Done") { showsDatePicker = false }
                    }
                    .padding(16)
                    .frame(width: 320)
                }
                Button { moveWeek(1) } label: { Image(systemName: "chevron.right") }
                    .help(String(localized: "Next Week"))
                    .accessibilityLabel(String(localized: "Next Week"))
                Spacer(minLength: 0)
            }
            .buttonStyle(.glass)

#if os(macOS)
            WeekColumnsLayout {
                ForEach(days, id: \.self) { day in
                    dayContent(day)
                }
            }
#else
            agenda
#endif
            Button("This Week") { selectedDate = Date() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
        }
    }

    private var agenda: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(days, id: \.self) { day in
                dayContent(day)
                if day != days.last { Divider() }
            }
        }
    }

    private func dayContent(_ day: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day, format: .dateTime.weekday(.abbreviated).day())
                .font(.subheadline.bold())
                .foregroundStyle(calendar.isDateInToday(day) ? Color.accentColor : .primary)
            let scheduled = scheduledTasks(on: day)
            if scheduled.isEmpty {
                Text("No tasks")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(scheduled) { task in
                NavigationLink {
                    TaskDetailView(store: store, task: task)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title).font(.subheadline.weight(.semibold)).lineLimit(3)
                        Text(PlanoraFormat.subjectDisplayName(task.subject)).font(.caption).foregroundStyle(.secondary)
                        if let date = HomeWeekCalendarSchedule.date(for: task) {
                            Text(date, format: .dateTime.hour().minute())
                                .font(.caption.monospacedDigit()).foregroundStyle(task.type.tint)
                        }
                        if task.isCompleted {
                            Label("Completed", systemImage: "checkmark.circle.fill")
                                .font(.caption).foregroundStyle(Color.planoraGreen)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(task.type.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scheduledTasks(on day: Date) -> [PlanoraTask] {
        HomeWeekCalendarSchedule.tasks(tasks, on: day, calendar: calendar)
    }

    private func moveWeek(_ offset: Int) {
        guard let date = calendar.date(byAdding: .weekOfYear, value: offset, to: selectedDate) else { return }
        selectedDate = date
    }
}

// Choose by available width, not by the intrinsic width of long task titles.
private struct WeekColumnsLayout: Layout {
    private let spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 900
        let horizontal = width >= 820
        let column = horizontal ? (width - spacing * CGFloat(max(0, subviews.count - 1))) / CGFloat(max(1, subviews.count)) : width
        let heights = subviews.map { $0.sizeThatFits(.init(width: column, height: nil)).height }
        let height = horizontal ? heights.max() ?? 0 : heights.reduce(0, +) + spacing * CGFloat(max(0, subviews.count - 1))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let horizontal = bounds.width >= 820
        let width = horizontal ? (bounds.width - spacing * CGFloat(max(0, subviews.count - 1))) / CGFloat(max(1, subviews.count)) : bounds.width
        var position = bounds.origin
        for view in subviews {
            let size = view.sizeThatFits(.init(width: width, height: nil))
            view.place(at: position, anchor: .topLeading, proposal: .init(width: width, height: size.height))
            if horizontal { position.x += width + spacing } else { position.y += size.height + spacing }
        }
    }
}

enum HomeWeekCalendarSchedule {
    static func days(containing date: Date, calendar: Calendar) -> [Date] {
        var calendar = calendar
        calendar.firstWeekday = 2
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start
            ?? calendar.startOfDay(for: date)
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    static func date(for task: PlanoraTask) -> Date? {
        task.hasDeadline ? task.deadline : task.plannedDate
    }

    static func tasks(_ tasks: [PlanoraTask], on day: Date, calendar: Calendar) -> [PlanoraTask] {
        tasks.filter { task in
            guard !task.isDeleted, !task.isArchived,
                  let date = date(for: task) else { return false }
            return calendar.isDate(date, inSameDayAs: day)
        }.sorted {
            let lhs = date(for: $0) ?? .distantFuture
            let rhs = date(for: $1) ?? .distantFuture
            if lhs != rhs { return lhs < rhs }
            return $0.id.uuidString < $1.id.uuidString
        }
    }
}
