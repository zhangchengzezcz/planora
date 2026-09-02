import SwiftUI

struct TaskAcademicPlanningEditor: View {
    let taskType: TaskType
    let subject: String
    let courseID: UUID?
    let topics: [PlanoraTopic]
    @Binding var selectedTopicIDs: Set<UUID>
    @Binding var examScope: String
    @Binding var targetScore: Double?
    @Binding var pastPaperTarget: Int
    @Binding var pastPapersCompleted: Int

    private var availableTopics: [PlanoraTopic] {
        topics.filter { $0.subject == subject || (courseID != nil && $0.courseID == courseID) }
    }

    var body: some View {
        if !availableTopics.isEmpty || taskType == .exam || taskType == .revision {
            VStack(alignment: .leading, spacing: 14) {
                if !availableTopics.isEmpty {
                    AcademicFieldLabel(title: String(localized: "Topics"))
                    FlowingTopicPicker(topics: availableTopics, selection: $selectedTopicIDs)
                }

                if taskType == .exam || taskType == .revision {
                    AcademicFieldLabel(title: String(localized: "Exam Planning"))
                    TextField(String(localized: "Exam Scope"), text: $examScope, axis: .vertical)
                        .lineLimit(2...5)

                    HStack {
                        Text(String(localized: "Target Score"))
                        Spacer()
                        TextField(String(localized: "Not Set"), value: $targetScore, format: .number)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 110)
                    }

                    Stepper(
                        PlanoraLocalization.format(String(localized: "Past Papers: %lld / %lld"), pastPapersCompleted, pastPaperTarget),
                        value: $pastPapersCompleted,
                        in: 0...max(pastPaperTarget, 0)
                    )
                    Stepper(
                        PlanoraLocalization.format(String(localized: "Past Paper Goal: %lld"), pastPaperTarget),
                        value: $pastPaperTarget,
                        in: 0...100
                    )
                    .onChange(of: pastPaperTarget) { _, value in
                        pastPapersCompleted = min(pastPapersCompleted, value)
                    }
                }
            }
        }
    }
}

private struct FlowingTopicPicker: View {
    let topics: [PlanoraTopic]
    @Binding var selection: Set<UUID>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
            ForEach(topics) { topic in
                Button {
                    if selection.contains(topic.id) { selection.remove(topic.id) }
                    else { selection.insert(topic.id) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: selection.contains(topic.id) ? "checkmark.circle.fill" : "circle")
                        Text(topic.title).lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 10)
                    .background(
                        selection.contains(topic.id) ? Color.planoraBlue.opacity(0.14) : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TaskAcademicPlanningPanel: View {
    let task: PlanoraTask
    let topics: [PlanoraTopic]

    private var linkedTopics: [PlanoraTopic] {
        let ids = Set(task.topicIDs)
        return topics.filter { ids.contains($0.id) }
    }

    var body: some View {
        if !linkedTopics.isEmpty || task.isExamPlanningTask {
            GlassPanel {
                VStack(alignment: .leading, spacing: 14) {
                    Label(String(localized: "Academic Planning"), systemImage: "graduationcap.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    if !linkedTopics.isEmpty {
                        ForEach(linkedTopics) { topic in
                            HStack {
                                Text(topic.title).font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(PlanoraFormat.percent(topic.mastery))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.planoraBlue)
                            }
                        }
                    }

                    if task.isExamPlanningTask {
                        if !task.examScope.isEmpty {
                            Divider()
                            LabeledContent(String(localized: "Exam Scope"), value: task.examScope)
                        }
                        if let targetScore = task.targetScore {
                            LabeledContent(String(localized: "Target Score"), value: targetScore.formatted())
                        }
                        LabeledContent(
                            String(localized: "Past Papers"),
                            value: "\(task.pastPapersCompleted) / \(task.pastPaperTarget)"
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

private struct AcademicFieldLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
