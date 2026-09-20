import SwiftData
import SwiftUI

enum AttendanceStatus: String, CaseIterable, Identifiable {
    case present, late, absent, unrecorded

    var id: String { rawValue }

    init(storedValue: String?) {
        self = Self(rawValue: storedValue?.lowercased() ?? "") ?? .unrecorded
    }

    var title: String {
        switch self {
        case .present: String(localized: "Present")
        case .late: String(localized: "Late")
        case .absent: String(localized: "Absent")
        case .unrecorded: String(localized: "Attendance Not Recorded")
        }
    }

    var tint: Color {
        switch self {
        case .present: .green
        case .late: .orange
        case .absent: .red
        case .unrecorded: .secondary
        }
    }

    var symbol: String {
        switch self {
        case .present: "checkmark.circle.fill"
        case .late: "clock.fill"
        case .absent: "xmark.circle.fill"
        case .unrecorded: "minus.circle"
        }
    }
}

struct AttendanceSummary {
    let counts: [AttendanceStatus: Int]

    init(events: [PlanoraScheduleEvent]) {
        // A lesson is counted once, even if an older store contains duplicate rows.
        var seen = Set<String>()
        var counts: [AttendanceStatus: Int] = [:]
        for event in events.sorted(by: { $0.lastSyncDate > $1.lastSyncDate }) {
            guard seen.insert(event.externalIdentifier).inserted else { continue }
            counts[AttendanceStatus(storedValue: event.attendanceStatus), default: 0] += 1
        }
        self.counts = counts
    }

    var recorded: Int { count(.present) + count(.late) + count(.absent) }
    var rate: Double? { recorded > 0 ? Double(count(.present) + count(.late)) / Double(recorded) : nil }
    func count(_ status: AttendanceStatus) -> Int { counts[status, default: 0] }
}

struct AttendanceView: View {
    @Query(sort: \PlanoraScheduleEvent.startDate) private var events: [PlanoraScheduleEvent]
    @State private var selectedWeek: Date?

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        return calendar
    }

    private var weeks: [Date] {
        Array(Set(events.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.startDate)?.start })).sorted(by: >)
    }

    private var week: Date? { selectedWeek ?? weeks.first }

    private var filtered: [PlanoraScheduleEvent] {
        guard let week, let end = calendar.date(byAdding: .day, value: 7, to: week) else { return [] }
        return events.filter { $0.startDate >= week && $0.startDate < end }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if events.isEmpty {
                    ContentUnavailableView(String(localized: "No Attendance Records"), systemImage: "person.badge.clock",
                        description: Text(String(localized: "Sync ManageBac to read classroom attendance.")))
                } else {
                    HStack {
                        Text(String(localized: "Class Attendance")).font(.title2.bold())
                        Spacer()
                        Picker(String(localized: "Week"), selection: Binding(get: { week }, set: { selectedWeek = $0 })) {
                            ForEach(weeks, id: \.self) { start in
                                Text(start, format: .dateTime.year().month().day()).tag(Optional(start))
                            }
                        }
                        .labelsHidden().fixedSize()
                    }
                    AttendanceMetrics(events: filtered)
                    ForEach(Array(Dictionary(grouping: filtered, by: \.title).keys.sorted()), id: \.self) { title in
                        let lessons = filtered.filter { $0.title == title }
                        VStack(alignment: .leading, spacing: 12) {
                            Text(title).font(.headline)
                            ForEach(lessons) { event in
                                let status = AttendanceStatus(storedValue: event.attendanceStatus)
                                HStack {
                                    Text(event.startDate, format: .dateTime.month().day().weekday().hour().minute())
                                        .foregroundStyle(.secondary)
                                    Spacer(minLength: 12)
                                    Label(status.title, systemImage: status.symbol).foregroundStyle(status.tint)
                                }
                                .font(.subheadline)
                            }
                        }
                        Divider()
                    }
                    if let syncDate = filtered.map(\.lastSyncDate).max() {
                        HStack {
                            Text(String(localized: "Last Synced"))
                            Text(syncDate, format: .dateTime.month().day().hour().minute())
                        }.font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(String(localized: "Attendance"))
    }
}

private struct AttendanceMetrics: View {
    let events: [PlanoraScheduleEvent]

    var body: some View {
        let summary = AttendanceSummary(events: events)
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                if let rate = summary.rate {
                    Text(rate, format: .percent.precision(.fractionLength(0)))
                        .font(.system(size: 32, weight: .bold, design: .rounded)).monospacedDigit()
                } else {
                    Text("—").font(.largeTitle)
                }
                Text(String(localized: "Attendance Rate")).foregroundStyle(.secondary)
            }
            if let rate = summary.rate { ProgressView(value: rate).tint(.green) }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 125), alignment: .leading)], alignment: .leading, spacing: 16) {
                ForEach(AttendanceStatus.allCases) { status in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(status.title, systemImage: status.symbol).font(.caption).foregroundStyle(status.tint)
                        Text(summary.count(status), format: .number).font(.title3.bold()).monospacedDigit()
                    }
                }
            }
            Text(String(localized: "Attendance includes late arrivals; unrecorded lessons are excluded."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct HomeAttendanceSection: View {
    @Query(sort: \PlanoraScheduleEvent.startDate) private var events: [PlanoraScheduleEvent]

    private var latestWeekEvents: [PlanoraScheduleEvent] {
        guard let latest = events.last else { return [] }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: latest.startDate) else { return [] }
        return events.filter { interval.contains($0.startDate) }
    }

    var body: some View {
        DashboardSection(title: String(localized: "Attendance")) {
            VStack(alignment: .leading, spacing: 16) {
                if let first = latestWeekEvents.first, let last = latestWeekEvents.last {
                    HStack {
                        Text(first.startDate, format: .dateTime.month().day())
                        Text("–")
                        Text(last.startDate, format: .dateTime.month().day())
                    }.font(.subheadline).foregroundStyle(.secondary)
                    AttendanceMetrics(events: latestWeekEvents)
                } else {
                    Text(String(localized: "Sync ManageBac to read classroom attendance."))
                        .foregroundStyle(.secondary)
                }
                NavigationLink(destination: AttendanceView()) {
                    Label(String(localized: "Attendance Details"), systemImage: "chevron.right")
                }
            }.padding(20)
        }
    }
}
