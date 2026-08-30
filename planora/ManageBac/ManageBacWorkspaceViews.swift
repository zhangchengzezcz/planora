import SwiftUI

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

    var body: some View {
        if messages.isEmpty {
            ContentUnavailableView(
                String(localized: "No Messages"),
                systemImage: "message",
                description: Text(String(localized: "Messages visible to your student account will appear after a sync."))
            )
            .frame(maxWidth: .infinity, minHeight: 280)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                    messageRow(message)
                    if index < messages.count - 1 { Divider().padding(.leading, 52) }
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

struct ManageBacTimetableList: View {
    let events: [PlanoraScheduleEvent]

    private var grouped: [(Date, [PlanoraScheduleEvent])] {
        Dictionary(grouping: events) { Calendar.current.startOfDay(for: $0.startDate) }
            .map { ($0.key, $0.value.sorted { $0.startDate < $1.startDate }) }
            .sorted { $0.0 < $1.0 }
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
                        Text(day, format: .dateTime.weekday(.wide).month().day())
                            .font(.headline).padding(.horizontal, 14).padding(.bottom, 8)
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, event in
                            HStack(alignment: .top, spacing: 14) {
                                Text(event.startDate, format: .dateTime.hour().minute())
                                    .font(.subheadline.monospacedDigit()).foregroundStyle(.secondary).frame(width: 58, alignment: .leading)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title).font(.headline)
                                    HStack(spacing: 8) {
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
