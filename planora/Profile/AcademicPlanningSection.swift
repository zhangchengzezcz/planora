import SwiftData
import SwiftUI

struct AcademicPlanningSection: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTopic.title) private var allTopics: [PlanoraTopic]
    @Query(sort: \PlanoraAssessment.date, order: .reverse) private var allAssessments: [PlanoraAssessment]

    let subject: String
    var courseID: UUID?

    @State private var topicEditor: TopicEditorState?
    @State private var assessmentEditor: AssessmentEditorState?

    private var topics: [PlanoraTopic] {
        allTopics.filter { $0.subject == subject || (courseID != nil && $0.courseID == courseID) }
    }

    private var assessments: [PlanoraAssessment] {
        allAssessments.filter { $0.subject == subject || (courseID != nil && $0.courseID == courseID) }
    }

    private var assessmentAverage: Double? {
        guard !assessments.isEmpty else { return nil }
        return assessments.map(\.percentage).reduce(0, +) / Double(assessments.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            topicSection
            assessmentSection
        }
        .sheet(item: $topicEditor) { state in
            TopicEditorView(state: state) { saveTopic($0) }
        }
        .sheet(item: $assessmentEditor) { state in
            AssessmentEditorView(state: state) { saveAssessment($0) }
        }
    }

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: String(localized: "Topics"),
                subtitle: String(localized: "Track syllabus mastery without predicting a final grade."),
                action: { topicEditor = TopicEditorState(subject: subject, courseID: courseID) }
            )

            if topics.isEmpty {
                AcademicEmptyRow(text: String(localized: "No topics yet"))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                        Button {
                            topicEditor = TopicEditorState(topic: topic)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(topic.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.planoraInk)
                                    ProgressView(value: topic.mastery)
                                        .tint(.planoraBlue)
                                }
                                Text(PlanoraFormat.percent(topic.mastery))
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(String(localized: "Delete"), role: .destructive) {
                                modelContext.delete(topic)
                                try? modelContext.save()
                            }
                        }
                        if index < topics.count - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .planoraAcademicSurface()
            }
        }
    }

    private var assessmentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(
                title: String(localized: "Assessments"),
                subtitle: assessmentAverage.map {
                    PlanoraLocalization.format(String(localized: "Current average: %@"), PlanoraFormat.percent($0))
                } ?? String(localized: "Record results and follow the trend over time."),
                action: { assessmentEditor = AssessmentEditorState(subject: subject, courseID: courseID) }
            )

            if assessments.isEmpty {
                AcademicEmptyRow(text: String(localized: "No assessments yet"))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(assessments.prefix(8).enumerated()), id: \.element.id) { index, assessment in
                        Button {
                            assessmentEditor = AssessmentEditorState(assessment: assessment)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(assessment.title)
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.planoraInk)
                                    Text("\(assessment.type.title) · \(PlanoraFormat.monthDay(assessment.date))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(PlanoraFormat.percent(assessment.percentage))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.planoraGreen)
                                    .monospacedDigit()
                            }
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(String(localized: "Delete"), role: .destructive) {
                                modelContext.delete(assessment)
                                try? modelContext.save()
                            }
                        }
                        if index < min(assessments.count, 8) - 1 { Divider() }
                    }
                }
                .padding(.horizontal, 16)
                .planoraAcademicSurface()
            }
        }
    }

    private func sectionHeader(title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.title3.weight(.bold)).foregroundStyle(Color.planoraInk)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: action) {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(PlanoraLocalization.format(String(localized: "Add %@"), title))
        }
    }

    private func saveTopic(_ state: TopicEditorState) {
        if let topic = state.topic {
            topic.title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
            topic.mastery = min(max(state.mastery, 0), 1)
            topic.notes = state.notes
        } else {
            modelContext.insert(PlanoraTopic(
                subject: state.subject,
                title: state.title.trimmingCharacters(in: .whitespacesAndNewlines),
                mastery: state.mastery,
                notes: state.notes,
                courseID: state.courseID
            ))
        }
        try? modelContext.save()
    }

    private func saveAssessment(_ state: AssessmentEditorState) {
        if let assessment = state.assessment {
            assessment.title = state.title.trimmingCharacters(in: .whitespacesAndNewlines)
            assessment.earnedScore = max(state.earnedScore, 0)
            assessment.maximumScore = max(state.maximumScore, 0.01)
            assessment.date = state.date
            assessment.type = state.type
            assessment.notes = state.notes
        } else {
            modelContext.insert(PlanoraAssessment(
                title: state.title.trimmingCharacters(in: .whitespacesAndNewlines),
                subject: state.subject,
                earnedScore: state.earnedScore,
                maximumScore: state.maximumScore,
                date: state.date,
                type: state.type,
                notes: state.notes,
                courseID: state.courseID
            ))
        }
        try? modelContext.save()
    }
}

private struct AcademicEmptyRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .planoraAcademicSurface()
    }
}

private extension View {
    @ViewBuilder func planoraAcademicSurface() -> some View {
#if os(macOS)
        background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.separator.opacity(0.45), lineWidth: 0.5))
#else
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
#endif
    }
}

private struct TopicEditorState: Identifiable {
    let id = UUID()
    var topic: PlanoraTopic?
    var subject: String
    var title = ""
    var mastery = 0.0
    var notes = ""
    var courseID: UUID?

    init(subject: String, courseID: UUID?) {
        self.subject = subject
        self.courseID = courseID
    }

    init(topic: PlanoraTopic) {
        self.topic = topic
        subject = topic.subject
        title = topic.title
        mastery = topic.mastery
        notes = topic.notes
        courseID = topic.courseID
    }
}

private struct TopicEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var state: TopicEditorState
    let onSave: (TopicEditorState) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "Topic Name"), text: $state.title)
                Section(String(localized: "Mastery")) {
                    Slider(value: $state.mastery, in: 0...1, step: 0.05)
                    Text(PlanoraFormat.percent(state.mastery)).monospacedDigit()
                }
                Section(String(localized: "Notes")) {
                    TextField(String(localized: "Notes"), text: $state.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(state.topic == nil ? String(localized: "Add Topic") : String(localized: "Edit Topic"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { onSave(state); dismiss() }
                        .disabled(state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .frame(minWidth: 420, minHeight: 360)
    }
}

private struct AssessmentEditorState: Identifiable {
    let id = UUID()
    var assessment: PlanoraAssessment?
    var subject: String
    var title = ""
    var earnedScore = 0.0
    var maximumScore = 100.0
    var date = Date()
    var type: AssessmentType = .quiz
    var notes = ""
    var courseID: UUID?

    init(subject: String, courseID: UUID?) {
        self.subject = subject
        self.courseID = courseID
    }

    init(assessment: PlanoraAssessment) {
        self.assessment = assessment
        subject = assessment.subject
        title = assessment.title
        earnedScore = assessment.earnedScore
        maximumScore = assessment.maximumScore
        date = assessment.date
        type = assessment.type
        notes = assessment.notes
        courseID = assessment.courseID
    }
}

private struct AssessmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var state: AssessmentEditorState
    let onSave: (AssessmentEditorState) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField(String(localized: "Assessment Name"), text: $state.title)
                Picker(String(localized: "Assessment Type"), selection: $state.type) {
                    ForEach(AssessmentType.allCases) { Text($0.title).tag($0) }
                }
                DatePicker(String(localized: "Date"), selection: $state.date, displayedComponents: .date)
                Section(String(localized: "Score")) {
                    TextField(String(localized: "Earned Score"), value: $state.earnedScore, format: .number)
                    TextField(String(localized: "Maximum Score"), value: $state.maximumScore, format: .number)
                }
                Section(String(localized: "Notes")) {
                    TextField(String(localized: "Notes"), text: $state.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .formStyle(.grouped)
            .navigationTitle(state.assessment == nil ? String(localized: "Add Assessment") : String(localized: "Edit Assessment"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(String(localized: "Cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Save")) { onSave(state); dismiss() }
                        .disabled(state.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || state.maximumScore <= 0)
                }
            }
        }
        .frame(minWidth: 440, minHeight: 450)
    }
}
