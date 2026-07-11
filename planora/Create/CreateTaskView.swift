import SwiftData
import SwiftUI

struct CreateTaskView: View {
    @Bindable var store: PlanoraStore
    var onClose: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var taskTypes: [TaskType] {
        TaskType.availableTypes(
            for: store.curriculum,
            selectedSubjects: store.selectedSubjectTitles
        )
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    Text(L("新建任务", "New Task"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.planoraInk)

                    Spacer(minLength: 12)

                    if let onClose {
                        CloseCreateButton(action: onClose)
                    }
                }

                NavigationLink {
                    QuickCreateTaskView(store: store, onComplete: onComplete)
                } label: {
                    GlassPanel(
                        padding: 16,
                        cornerRadius: PlanoraTheme.compactCornerRadius,
                        tint: Color.planoraAmber.opacity(0.12),
                        interactive: true
                    ) {
                        HStack(spacing: 14) {
                            Image(systemName: "bolt.fill")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Color.planoraAmber)
                                .frame(width: 44, height: 44)
                                .background(Color.planoraAmber.opacity(0.14), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(L("快速新建", "Quick Create"))
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Color.planoraInk)
                                Text(L("只填写标题、科目和日期。", "Just add a title, subject, and date."))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(taskTypes) { type in
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
            CreateTaskFormView(store: store, taskType: type, onComplete: onComplete)
        }
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
    }
}

private struct CloseCreateButton: View {
    let action: () -> Void

    var body: some View {
        let shape = Circle()

        Button(action: action) {
            Image(systemName: "xmark")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.planoraInk)
                .frame(width: 42, height: 42)
                .background(Color.planoraGlassFill, in: shape)
                .glassEffect(.regular.tint(Color.planoraGlassTint).interactive(), in: shape)
                .overlay(shape.stroke(Color.planoraGlassStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("关闭", "Close"))
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
    let onComplete: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @State private var title = ""
    @State private var selectedSubject = ""
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var hasPlannedDate = false
    @State private var plannedDate = Date()
    @State private var tracksProgress: Bool
    @State private var progressKind: ProgressKind
    @State private var percentageProgress: Double
    @State private var stageName: String
    @State private var priority: TaskPriority = .medium
    @State private var notes = ""
    @State private var reminders: [TaskReminder] = []
    @State private var recurrenceRule: TaskRecurrenceRule?
    @State private var hasEditedTitle = false

    private let subjectColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    init(store: PlanoraStore, taskType: TaskType, onComplete: (() -> Void)? = nil) {
        self.store = store
        self.taskType = taskType
        self.onComplete = onComplete
        let defaultState = taskType.defaultProgressState
        _hasDeadline = State(initialValue: taskType.usesDeadlineByDefault)
        _deadline = State(initialValue: Calendar.current.date(byAdding: .day, value: taskType.recommendedDeadlineOffset, to: Date()) ?? Date())
        _tracksProgress = State(initialValue: taskType.tracksProgressByDefault)
        _progressKind = State(initialValue: defaultState.kind)
        _percentageProgress = State(initialValue: defaultState.percentageValue ?? 0)
        _stageName = State(initialValue: defaultState.stageValue ?? taskType.defaultStage)
    }

    private var subjectOptions: [String] {
        taskType.subjectOptions(
            for: store.curriculum,
            selectedSubjects: store.selectedSubjectTitles,
            selectedExtraLearning: store.selectedExtraLearningTitles
        )
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
                        PlanoraFieldLabel(L("标题", "Title"))
                        TextField(taskType.titlePlaceholder, text: titleBinding)
                            .textFieldStyle(.plain)
                            .font(.title3.weight(.semibold))

                        Divider()

                        PlanoraFieldLabel(L("科目", "Subject"))
                        LazyVGrid(columns: subjectColumns, spacing: 10) {
                            ForEach(subjectOptions, id: \.self) { subject in
                                SelectableChip(title: PlanoraFormat.subjectDisplayName(subject), isSelected: selectedSubject == subject) {
                                    selectedSubject = subject
                                    updateTitleFromSelectionIfNeeded()
                                }
                            }
                        }
                        .onAppear {
                            if selectedSubject.isEmpty, let firstSubject = subjectOptions.first {
                                selectedSubject = firstSubject
                                updateTitleFromSelectionIfNeeded()
                            }
                        }

                        Divider()

                        Toggle(L("截止日期", "Deadline"), isOn: $hasDeadline)
                            .font(.headline)
                            .tint(taskType.tint)
                            .disabled(recurrenceRule != nil)

                        if hasDeadline {
                            DatePicker(L("日期", "Date"), selection: $deadline, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        Toggle(L("计划完成日期", "Planned Date"), isOn: $hasPlannedDate)
                            .font(.headline)
                            .tint(taskType.tint)

                        if hasPlannedDate {
                            DatePicker(L("计划日期", "Plan For"), selection: $plannedDate, displayedComponents: .date)
                                .datePickerStyle(.compact)
                        }

                        NavigationLink {
                            ReminderDraftEditorView(
                                reminders: $reminders,
                                deadline: hasDeadline ? deadline : nil,
                                tint: taskType.tint
                            )
                        } label: {
                            HStack {
                                Label(L("提醒", "Reminders"), systemImage: "bell.badge")
                                    .font(.headline)
                                    .foregroundStyle(Color.planoraInk)

                                Spacer()

                                Text(reminderSummary)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()

                        NavigationLink {
                            RecurrenceDraftEditorView(
                                rule: $recurrenceRule,
                                startDate: deadline,
                                tint: taskType.tint
                            )
                        } label: {
                            HStack {
                                Label(L("重复", "Repeat"), systemImage: "repeat")
                                    .font(.headline)
                                    .foregroundStyle(Color.planoraInk)

                                Spacer()

                                Text(recurrenceRule?.summary ?? L("不重复", "Does Not Repeat"))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider()

                        PlanoraFieldLabel(L("优先级", "Priority"))
                        Picker(L("优先级", "Priority"), selection: $priority) {
                            ForEach(TaskPriority.allCases) { priority in
                                Text(priority.title).tag(priority)
                            }
                        }
                        .pickerStyle(.segmented)

                        Divider()

                        Toggle(L("跟踪进度", "Track Progress"), isOn: $tracksProgress)
                            .font(.headline)
                            .tint(taskType.tint)

                        if tracksProgress {
                            PlanoraFieldLabel(L("进度", "Progress"))
                            Picker(L("进度类型", "Progress Type"), selection: $progressKind) {
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
                        }

                        Divider()

                        PlanoraFieldLabel(L("备注", "Notes"))
                        TextField(L("备注", "Notes"), text: $notes, axis: .vertical)
                            .textFieldStyle(.plain)
                            .lineLimit(3...6)
                    }
                }

                PlanoraPrimaryButton(title: L("保存任务", "Save Task"), systemImage: "checkmark", isDisabled: !canSave) {
                    saveTask()
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
        .onChange(of: recurrenceRule) { _, newRule in
            if newRule != nil { hasDeadline = true }
        }
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
            tracksProgress: tracksProgress,
            progressState: progressState,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            importance: priority.rawValue,
            plannedDate: hasPlannedDate ? plannedDate : nil
        )

        modelContext.insert(task)
        task.replaceReminders(
            with: hasDeadline ? reminders : reminders.filter { !$0.isRelativeToDeadline }
        )
        var createdTasks = [task]
        if let recurrenceRule {
            task.recurrenceRule = recurrenceRule
            task.recurrenceSeriesID = UUID()
            task.recurrenceOccurrenceDate = task.deadline
            createdTasks = RecurringTaskEngine.materializeSeries(from: task, in: modelContext)
        }
        try? modelContext.save()
        QuickCreatePreferences.save(
            subject: selectedSubject,
            type: taskType,
            reminders: task.reminders,
            hasDeadline: hasDeadline
        )
        let refreshedTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? createdTasks
        Task { await TaskReminderScheduler.reconcile(tasks: refreshedTasks) }
        store.selectedTab = .home
        onComplete?()
    }

    private var reminderSummary: String {
        reminders.isEmpty ? L("未设置", "Not Set") : LF("reminder_count_format", reminders.count)
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

                Text(L("新建任务", "New Task"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
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
                Text(L("进度", "Progress"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)

                Spacer()

                Text(PlanoraFormat.percent(value))
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
            Picker(L("阶段", "Stage"), selection: $stageName) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.menu)

            TextField(L("自定义阶段", "Custom stage"), text: $stageName)
                .textFieldStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
    }
}
