import SwiftUI

struct HomeWeekCalendar: View {
    let store: PlanoraStore
    let tasks: [PlanoraTask]
    @Binding var selectedDate: Date
    var onSelectTask: (PlanoraTask) -> Void = { _ in }
    @State private var showsDatePicker = false
    @State private var availableWidth: CGFloat = 0

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

            let columns = availableWidth >= 820
            let layout = columns ? AnyLayout(HStackLayout(alignment: .top, spacing: 12))
                : AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            layout {
                ForEach(days, id: \.self) { day in
                    dayContent(day)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
            Button("This Week") { selectedDate = Date() }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { geometry in
            geometry.size.width
        } action: { width in
            if width.isFinite { availableWidth = width }
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
                Button {
                    onSelectTask(task)
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
