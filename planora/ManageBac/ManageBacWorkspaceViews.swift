import SwiftUI
import SwiftData

struct ManageBacMessagesView: View {
    @Query(sort: \PlanoraMessage.publishedDate, order: .reverse) private var messages: [PlanoraMessage]

    var body: some View {
        ScrollView {
            ManageBacMessageList(messages: messages)
        }
        .navigationTitle(String(localized: "Messages"))
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }
}

enum CoursesWorkspaceSection: String, CaseIterable, Identifiable {
    case courses
    case timetable
    case messages

    var id: String { rawValue }

    var title: String {
        switch self {
        case .courses: String(localized: "Courses")
        case .timetable: String(localized: "Timetable")
        case .messages: String(localized: "Messages")
        }
    }
}

struct ManageBacMessageList: View {
    let messages: [PlanoraMessage]

    private var orderedMessages: [PlanoraMessage] {
        ManageBacMessageOrdering.sorted(messages)
    }

    var body: some View {
        if orderedMessages.isEmpty {
            ContentUnavailableView(
                String(localized: "No Messages"),
                systemImage: "message",
                description: Text(String(localized: "Messages visible to your student account will appear after a sync."))
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(orderedMessages.enumerated()), id: \.element.id) { index, message in
                    messageRow(message)
                    if index < orderedMessages.count - 1 { Divider().padding(.leading, 52) }
                }
            }
        }
    }

    @ViewBuilder
    private func messageRow(_ message: PlanoraMessage) -> some View {
        let content = HStack(alignment: .top, spacing: 12) {
            Image(systemName: message.isUnread ? "envelope.badge.fill" : "envelope")
                .foregroundStyle(message.isUnread ? Color.accentColor : .secondary)
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(message.title).font(.headline).lineLimit(2)
                if !message.senderName.isEmpty {
                    Text(message.senderName).font(.caption).foregroundStyle(.secondary)
                }
                if !message.bodyPreview.isEmpty {
                    Text(message.bodyPreview).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                if let date = message.publishedDate {
                    Text(date, format: .dateTime.year().month().day().hour().minute())
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())

        if let value = message.externalURLString, let url = URL(string: value) {
            Link(destination: url) { content }.buttonStyle(.plain)
        } else {
            content
        }
    }
}

enum ManageBacMessageOrdering {
    private struct Key: Sendable {
        let publishedDate: Date?
        let numericIdentifier: UInt64?
        let lastSyncDate: Date
        let externalIdentifier: String
    }

    @MainActor
    static func sorted(_ messages: [PlanoraMessage]) -> [PlanoraMessage] {
        messages
            .map { message in
                (
                    message: message,
                    key: Key(
                        publishedDate: message.publishedDate,
                        numericIdentifier: UInt64(message.externalIdentifier),
                        lastSyncDate: message.lastSyncDate,
                        externalIdentifier: message.externalIdentifier
                    )
                )
            }
            .sorted { newestFirst($0.key, $1.key) }
            .map(\.message)
    }

    nonisolated private static func newestFirst(_ lhs: Key, _ rhs: Key) -> Bool {
        if let lhsDate = lhs.publishedDate,
           let rhsDate = rhs.publishedDate,
           lhsDate != rhsDate {
            return lhsDate > rhsDate
        }

        if lhs.publishedDate != nil, rhs.publishedDate == nil { return true }
        if lhs.publishedDate == nil, rhs.publishedDate != nil { return false }

        // ManageBac frequently omits the time, so every message from one day
        // receives the same timestamp. Its numeric notification identifier is
        // monotonic and provides a stable newest-first order for those ties.
        if let lhsIdentifier = lhs.numericIdentifier,
           let rhsIdentifier = rhs.numericIdentifier,
           lhsIdentifier != rhsIdentifier {
            return lhsIdentifier > rhsIdentifier
        }

        if lhs.lastSyncDate != rhs.lastSyncDate { return lhs.lastSyncDate > rhs.lastSyncDate }
        return lhs.externalIdentifier.localizedStandardCompare(rhs.externalIdentifier) == .orderedDescending
    }
}

struct ManageBacTimetableList: View {
    let events: [PlanoraScheduleEvent]
    @Environment(\.locale) private var locale

    private var grouped: [(Int, [PlanoraScheduleEvent])] {
        ManageBacWeeklyTimetable.days(events: events)
    }

    private func weekdayName(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        return formatter.standaloneWeekdaySymbols[weekday - 1]
    }

    var body: some View {
        if events.isEmpty {
            ContentUnavailableView(
                String(localized: "No Timetable"),
                systemImage: "calendar.badge.clock",
                description: Text(String(localized: "A timetable appears only when your school enables it in ManageBac."))
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(grouped, id: \.0) { day, items in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(weekdayName(day))
                            .font(.headline).padding(.horizontal, 14).padding(.bottom, 8)
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 14) {
                                Text(event.startDate, format: .dateTime.hour().minute())
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).frame(width: 58, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.headline)
                                    VStack(alignment: .leading, spacing: 4) {
                                        if let location = event.location, !location.isEmpty { Label(location, systemImage: "door.left.hand.open") }
                                        if !event.teacherNames.isEmpty { Label(event.teacherNames.joined(separator: ", "), systemImage: "person") }
                                    }
                                    .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(event.endDate, format: .dateTime.hour().minute())
                                    .font(.caption.monospacedDigit()).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 11)
                            if index < items.count - 1 { Divider().padding(.leading, 86) }
                        }
                    }
                }
            }
        }
    }
}

enum ManageBacWeeklyTimetable {
    static func days(events: [PlanoraScheduleEvent], calendar: Calendar = .current) -> [(Int, [PlanoraScheduleEvent])] {
        let byWeekday = Dictionary(grouping: events) { calendar.component(.weekday, from: $0.startDate) }
        return (2...6).map { weekday in
            let byDate = Dictionary(grouping: byWeekday[weekday] ?? []) { calendar.startOfDay(for: $0.startDate) }
            // Stored snapshots can span several weeks. Show the most recently synced
            // source day, not every historical occurrence of the same weekday.
            let latestDay = byDate.keys.max { lhs, rhs in
                let left = byDate[lhs]!.map(\.lastSyncDate).max()!
                let right = byDate[rhs]!.map(\.lastSyncDate).max()!
                return left == right ? lhs < rhs : left < right
            }
            let items = latestDay.flatMap { byDate[$0] } ?? []
            return (weekday, items.sorted {
                if $0.startDate != $1.startDate { return $0.startDate < $1.startDate }
                return $0.title.localizedStandardCompare($1.title) == .orderedAscending
            })
        }
    }
}
