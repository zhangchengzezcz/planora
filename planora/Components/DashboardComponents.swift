import SwiftUI

struct ManageBacTaskResultLabel: View {
    let task: PlanoraTask

    var body: some View {
        if task.isManageBacTask {
            VStack(alignment: .leading, spacing: 4) {
                if let result = task.manageBacAssessmentSummary {
                    Label(result, systemImage: "chart.bar.doc.horizontal")
                        .accessibilityLabel(String(localized: "ManageBac Result") + ": " + result)
                }
                if task.isManageBacCompleted {
                    Label("ManageBac · " + String(localized: "Completed"), systemImage: "checkmark.seal")
                }
            }
            .font(.callout.weight(.semibold))
            .foregroundStyle(Color.planoraDeepGreen)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct ManageBacTaskResultPanel: View {
    let task: PlanoraTask

    var body: some View {
        if task.isManageBacTask,
           task.manageBacAssessmentSummary != nil || task.isManageBacCompleted {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(localized: "ManageBac Result"))
                    .font(.headline)
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .firstTextBaseline, spacing: 24) { values }
                    VStack(alignment: .leading, spacing: 12) { values }
                }
                if task.remoteStatusRawValue == ManageBacRemoteTaskStatus.completed.rawValue {
                    Label("ManageBac · " + String(localized: "Completed"), systemImage: "checkmark.seal.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.planoraDeepGreen)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder private var values: some View {
        if let grade = task.remoteGradeText, !grade.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "ManageBac Grade")).font(.subheadline).foregroundStyle(.secondary)
                Text(grade).font(.system(size: 32, weight: .bold)).monospacedDigit()
            }
        }
        if let earned = task.remoteScoreEarned {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "Score")).font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(earned.formatted()).font(.system(size: 28, weight: .bold))
                    if let possible = task.remoteScorePossible {
                        Text("/ " + possible.formatted()).font(.title3).foregroundStyle(.secondary)
                    }
                }
                .monospacedDigit()
            }
        }
    }
}
import SwiftData

struct ProfileHeaderActions: View {
    let store: PlanoraStore

    var body: some View {
        HStack(spacing: 10) {
            ProfileAvatarLink(store: store)
            MessageBellLink()
        }
        .fixedSize()
    }
}

struct MessageBellLink: View {
    @Query(filter: #Predicate<PlanoraMessage> { $0.isUnread }) private var unreadMessages: [PlanoraMessage]

    var body: some View {
        NavigationLink {
            ManageBacMessagesView()
        } label: {
            Image(systemName: "bell")
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .glassEffect(.regular.interactive(), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if !unreadMessages.isEmpty {
                        Circle().fill(.red).frame(width: 8, height: 8)
                            .padding(3)
                            .accessibilityHidden(true)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Messages"))
        .accessibilityValue(Text(unreadMessages.count, format: .number))
    }
}

struct ProfileAvatarLink: View {
    let store: PlanoraStore
    var size: CGFloat = 38

    var body: some View {
        NavigationLink {
            ProfileView(store: store)
        } label: {
            ProfileAvatarView(name: store.userName, size: size)
                .overlay(Circle().stroke(Color.planoraGlassStroke, lineWidth: 1))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Profile"))
    }
}

struct DashboardSection<Content: View>: View {
    let title: String
    let trailing: String?
    let content: Content

    init(title: String, trailing: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.trailing = trailing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.planoraInk)

                Spacer()

                if let trailing {
                    Text(trailing)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            GlassPanel(padding: 0) {
                content
            }
        }
    }
}

struct ProgressSubjectRow: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Spacer()

                Text(PlanoraFormat.percent(value))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            ProgressView(value: value)
                .tint(tint)
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let value: String
    var showsChevron = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(Color.planoraBlue)
                .frame(width: 38, height: 38)
                .background(Color.planoraBlue.opacity(0.1), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.planoraInk)

            Spacer()

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.76)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}
