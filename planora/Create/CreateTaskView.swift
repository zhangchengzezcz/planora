import SwiftData
import SwiftUI

struct CreateTaskView: View {
    @Bindable var store: PlanoraStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create New")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.planoraInk)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(TaskType.allCases) { type in
                        NavigationLink(value: type) {
                            CreateTypeCard(type: type)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .navigationDestination(for: TaskType.self) { type in
            CreateTaskFormView(store: store, taskType: type)
        }
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
    }
}

private struct CreateTypeCard: View {
    let type: TaskType

    var body: some View {
        GlassPanel(padding: 16, cornerRadius: PlanoraTheme.compactCornerRadius, tint: type.tint.opacity(0.12), interactive: true) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: type.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(type.tint)
                    .frame(width: 42, height: 42)
                    .background(type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(type.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 104)
        }
    }
}

private struct CreateTaskFormView: View {
    @Bindable var store: PlanoraStore
    let taskType: TaskType

    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var selectedSubject = ""
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var progressKind: ProgressKind
    @State private var percentageProgress: Double
    @State private var stageName: String
    @State private var notes = ""
    @State private var hasEditedTitle = false

    private let subjectColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    init(store: PlanoraStore, taskType: TaskType) {
        self.store = store
        self.taskType = taskType
        let defaultState = taskType.defaultProgressState
        _hasDeadline = State(initialValue: taskType.usesDeadlineByDefault)
        _deadline = State(initialValue: Calendar.current.date(byAdding: .day, value: taskType.recommendedDeadlineOffset, to: Date()) ?? Date())
        _progressKind = State(initialValue: defaultState.kind)
        _percentageProgress = State(initialValue: defaultState.percentageValue ?? 0)
        _stageName = State(initialValue: defaultState.stageValue ?? taskType.defaultStage)
    }

    private var subjectOptions: [String] {
        let subjects = store.selectedSubjectTitles
        guard !subjects.isEmpty else { return ["General"] }
        return taskType.allowsGeneralSubject ? ["General"] + subjects : subjects
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                FormHeader(type: taskType)

                GlassPanel {
                    VStack(alignment: .leading, spacing: 18) {
                        PlanoraFieldLabel("Title")
                        TextField(taskType.titlePlaceholder, text: titleBinding)
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))

                        Divider()

                        PlanoraFieldLabel("Subject")
                        LazyVGrid(columns: subjectColumns, spacing: 10) {
                            ForEach(subjectOptions, id: \.self) { subject in
                                SelectableChip(title: subject, isSelected: selectedSubject == subject) {
                                    selectedSubject = subject
                                    updateTitleFromSelectionIfNeeded()
                                }
                            }
                        }
                        .onAppear {
                            if selectedSubject.isEmpty {
                                selectedSubject = subjectOptions[0]
                                updateTitleFromSelectionIfNeeded()
                            }
                        }

                        Divider()

                        Toggle("Deadline", isOn: $hasDeadline)
                            .font(.headline)
                            .tint(taskType.tint)

                        if hasDeadline {
                            DatePicker("Date", selection: $deadline, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        Divider()

                        PlanoraFieldLabel("Progress")
                        Picker("Progress Type", selection: $progressKind) {
                            ForEach(ProgressKind.allCases) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)

                        if progressKind == .percentage {
                            PercentageProgressEditor(value: $percentageProgress, tint: taskType.tint)
                        } else {
                            StageProgressEditor(stageName: $stageName, options: taskType.stageOptions, tint: taskType.tint)
                        }

                        Divider()

                        PlanoraFieldLabel("Notes")
                        TextField("Notes", text: $notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                    }
                }

                PlanoraPrimaryButton(title: "Save Task", systemImage: "checkmark", isDisabled: !canSave) {
                    saveTask()
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
    }

    private var titleBinding: Binding<String> {
        Binding(
            get: { title },
            set: { newValue in
                title = newValue
                hasEditedTitle = true
            }
        )
    }

    private func updateTitleFromSelectionIfNeeded() {
        guard !hasEditedTitle || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        title = taskType.defaultTitle(for: selectedSubject)
        hasEditedTitle = false
    }

    private func saveTask() {
        guard canSave else { return }

        let progressState: ProgressState = progressKind == .percentage
            ? .percentage(percentageProgress)
            : .stage(stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? taskType.defaultStage : stageName)

        let task = PlanoraTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: selectedSubject,
            type: taskType,
            deadline: deadline,
            hasDeadline: hasDeadline,
            progressState: progressState,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        )

        modelContext.insert(task)
        try? modelContext.save()
        store.selectedTab = .home
    }
}

private struct FormHeader: View {
    let type: TaskType

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: type.symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(type.tint)
                .frame(width: 52, height: 52)
                .background(type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(type.title)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.planoraInk)

                Text("Create New")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct PlanoraFieldLabel: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct PercentageProgressEditor: View {
    @Binding var value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Progress")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
            }

            Slider(value: $value, in: 0...1, step: 0.05)
                .tint(tint)
        }
    }
}

private struct StageProgressEditor: View {
    @Binding var stageName: String
    let options: [String]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Stage", selection: $stageName) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)

            TextField("Custom stage", text: $stageName)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}
