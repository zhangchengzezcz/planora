import SwiftUI

struct HomeDashboardView: View {
    let store: PlanoraStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HomeHeader(store: store)

                TodayFocusCard(task: store.upcomingTasks[0])

                DashboardSection(title: "Upcoming Tasks") {
                    VStack(spacing: 0) {
                        ForEach(Array(store.upcomingTasks.enumerated()), id: \.element.id) { index, task in
                            TaskRow(task: task)

                            if index != store.upcomingTasks.indices.last {
                                Divider().padding(.leading, 56)
                            }
                        }
                    }
                }

                DashboardSection(title: "Learning Progress", trailing: "12 / 15 completed") {
                    VStack(spacing: 18) {
                        ForEach(store.progressSnapshots) { snapshot in
                            ProgressSubjectRow(title: snapshot.title, value: snapshot.value, tint: snapshot.tint)
                        }
                    }
                    .padding(20)
                }

                DashboardSection(title: "Calendar Preview") {
                    CalendarPreview(events: store.calendarEvents)
                        .padding(18)
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
    let task: DashboardTask

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
                    }

                    Spacer()

                    Image(systemName: "target")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(Color.planoraBlue)
                        .frame(width: 48, height: 48)
                        .background(Color.planoraBlue.opacity(0.12), in: Circle())
                }

                Text("3 days left. Finish the next focused block and keep the learning space moving.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ProgressSubjectRow(title: "Completion", value: task.progress, tint: task.tint)
            }
        }
    }
}

private struct TaskRow: View {
    let task: DashboardTask

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(task.tint)
                    .frame(width: 42, height: 42)
                    .background(task.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Text(task.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(task.progressText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(task.tint)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }

            ProgressView(value: task.progress)
                .tint(task.tint)
        }
        .padding(18)
    }
}

private struct CalendarPreview: View {
    let events: [CalendarEvent]

    private let weekdays = ["M", "T", "W", "T", "F", "S", "S"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var eventDays: Set<Int> {
        Set(events.map(\.day))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("July")
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
        (1...31).map(CalendarDay.init(value:))
    }
}

private struct CalendarDay: Identifiable {
    let value: Int
    var id: String { "day-\(value)" }
}
