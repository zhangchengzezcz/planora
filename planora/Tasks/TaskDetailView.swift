import SwiftData
import SwiftUI

struct TaskDetailView: View {
    @Bindable var store: PlanoraStore
    @Bindable var task: PlanoraTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTask.createdDate) private var allTasks: [PlanoraTask]
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                detailHeader
                overviewPanel

                if task.tracksProgress {
                    progressPanel
                }

                notesPanel
                completionButton
                deleteButton
            }
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .navigationTitle(String(localized: "Task Details"))
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
        .onAppear {
            task.ensureTimeline()
            PlanoraTaskPersistence.save(modelContext)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    EditTaskView(store: store, task: task)
                } label: {
                    Text(String(localized: "Edit"))
                        .fontWeight(.semibold)
                }
            }
        }
        .confirmationDialog(
            task.isRecurring ? String(localized: "Delete Repeating Task") : String(localized: "Delete Task?"),
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            if task.isRecurring {
                Button(String(localized: "Delete This Occurrence"), role: .destructive) {
                    delete(scope: .occurrence)
                }
                Button(String(localized: "Delete This and Future"), role: .destructive) {
                    delete(scope: .future)
                }
                Button(String(localized: "Delete Entire Series"), role: .destructive) {
                    delete(scope: .entireSeries)
                }
            } else {
                Button(String(localized: "Delete"), role: .destructive) {
                    delete(scope: .occurrence)
                }
            }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(PlanoraLocalization.format(String(localized: "delete_task_confirmation_format"), task.title))
        }
    }

    private var detailHeader: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: task.type.symbol)
                .font(.title2.weight(.bold))
                .foregroundStyle(task.type.tint)
                .frame(width: 54, height: 54)
                .background(task.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.planoraInk)
                    .fixedSize(horizontal: false, vertical: true)

                Text(PlanoraFormat.subjectDisplayName(task.subject))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            PriorityPill(priority: task.priority)
        }
    }

    private var overviewPanel: some View {
        GlassPanel {
            VStack(spacing: 0) {
                DetailRow(icon: "square.grid.2x2.fill", title: String(localized: "Type"), value: task.type.title, tint: task.type.tint)
                Divider().padding(.leading, 50)
                DetailRow(icon: "calendar", title: String(localized: "Deadline"), value: deadlineText, tint: task.type.tint)
                Divider().padding(.leading, 50)
                DetailRow(icon: "calendar.badge.clock", title: String(localized: "Planned Date"), value: plannedDateText, tint: .planoraDeepGreen)
                Divider().padding(.leading, 50)
                DetailRow(icon: "repeat", title: String(localized: "Repeat"), value: task.recurrenceSummary, tint: .planoraBlue)
                Divider().padding(.leading, 50)
                DetailRow(icon: "flag.fill", title: String(localized: "Priority"), value: task.priority.title, tint: task.priority.tint)
                Divider().padding(.leading, 50)
                NavigationLink {
                    TaskReminderEditorView(task: task)
                } label: {
                    DetailRow(
                        icon: "bell.badge.fill",
                        title: String(localized: "Reminders"),
                        value: task.reminderSummary,
                        tint: .planoraAmber,
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 50)
                DetailRow(icon: "clock.fill", title: String(localized: "Created"), value: PlanoraFormat.monthDay(task.createdDate), tint: .planoraDeepGreen)
            }
        }
    }

    private var progressPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(localized: "Learning Progress"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.planoraInk)

                        Text(task.progressState.label)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(task.progressState.valueText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(task.type.tint)

                    if task.progressState.kind == .stage {
                        NavigationLink {
                            TimelineEditorView(task: task)
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(task.type.tint)
                                .frame(width: 34, height: 34)
                                .background(task.type.tint.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Edit Timeline"))
                        .help(String(localized: "Edit Timeline"))
                    }
                }

                if let progress = task.progressState.percentageValue {
                    ProgressView(value: progress)
                        .tint(task.type.tint)
                } else {
                    ProgressView(value: task.progressFraction)
                        .tint(task.type.tint)

                    stageTrack
                }
            }
        }
    }

    private var stageTrack: some View {
        let milestones = task.timeline

        return VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                Button {
                    task.toggleMilestone(id: milestone.id)
                    PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                } label: {
                    TimelineMilestoneRow(
                        milestone: milestone,
                        isCurrent: !milestone.isCompleted && milestones.firstIndex(where: { !$0.isCompleted }) == index,
                        isLast: index == milestones.count - 1,
                        tint: task.type.tint
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var notesPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label(String(localized: "Notes"), systemImage: "note.text")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(task.notes.isEmpty ? String(localized: "No Notes") : task.notes)
                    .font(.subheadline)
                    .foregroundStyle(task.notes.isEmpty ? .secondary : Color.planoraInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var completionButton: some View {
        PlanoraPrimaryButton(
            title: task.isCompleted ? String(localized: "Mark Incomplete") : String(localized: "Mark Complete"),
            systemImage: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill"
        ) {
            task.setCompleted(!task.isCompleted)
            PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
        }
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            isShowingDeleteConfirmation = true
        } label: {
            Label(String(localized: "Delete Task"), systemImage: "trash")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 50)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
    }

    private var deadlineText: String {
        guard task.hasDeadline, let deadline = task.deadline else {
            return String(localized: "No deadline")
        }

        return deadline.formatted(date: .long, time: .omitted)
    }

    private var plannedDateText: String {
        task.plannedDate?.formatted(date: .long, time: .omitted) ?? String(localized: "Not Planned")
    }

    private func delete(scope: RecurrenceEditScope) {
        PlanoraTaskOperations.delete(
            task,
            scope: scope,
            allTasks: allTasks,
            modelContext: modelContext,
            store: store
        )
        dismiss()
    }
}

struct TaskCompletionButton: View {
    @Bindable var task: PlanoraTask
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        Button {
            task.setCompleted(!task.isCompleted)
            PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
        } label: {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(task.isCompleted ? Color.planoraGreen : Color.gray)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(task.isCompleted ? String(localized: "Mark Incomplete") : String(localized: "Mark Complete"))
    }
}

private struct TimelineMilestoneRow: View {
    let milestone: AcademicMilestone
    let isCurrent: Bool
    let isLast: Bool
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : isCurrent ? "circle.inset.filled" : "circle")
                    .font(.headline)
                    .foregroundStyle(milestone.isCompleted || isCurrent ? tint : Color.gray)

                if !isLast {
                    Rectangle()
                        .fill(milestone.isCompleted ? tint.opacity(0.55) : Color.gray.opacity(0.22))
                        .frame(width: 2, height: 28)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.localizedTitle)
                    .font(.subheadline.weight(isCurrent ? .bold : .semibold))
                    .foregroundStyle(milestone.isCompleted || isCurrent ? Color.planoraInk : .secondary)

                if let targetDate = milestone.targetDate {
                    Text(PlanoraFormat.monthDay(targetDate))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(isCurrent ? tint : .secondary)
                }
            }
            .padding(.bottom, isLast ? 0 : 8)

            Spacer()
        }
        .contentShape(Rectangle())
    }
}

private struct TimelineEditorView: View {
    @Bindable var task: PlanoraTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var milestones: [AcademicMilestone]

    init(task: PlanoraTask) {
        self.task = task
        _milestones = State(initialValue: task.timeline)
    }

    private var canSave: Bool {
        !milestones.isEmpty
            && milestones.allSatisfy { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && datesFollowTimelineOrder
    }

    private var datesFollowTimelineOrder: Bool {
        let dates = milestones.compactMap(\.targetDate)
        return zip(dates, dates.dropFirst()).allSatisfy { $0 <= $1 }
    }

    private var allowedDateRange: ClosedRange<Date> {
        let proposedEnd = task.deadline
            ?? Calendar.current.date(byAdding: .year, value: 10, to: Date())
            ?? Date.distantFuture
        return min(task.createdDate, proposedEnd)...max(task.createdDate, proposedEnd)
    }

    var body: some View {
        Form {
            Section {
                ForEach($milestones) { $milestone in
                    MilestoneEditorRow(
                        milestone: $milestone,
                        allowedDateRange: allowedDateRange,
                        fallbackDate: task.deadline ?? Date()
                    )
                }
                .onDelete(perform: deleteMilestones)
                .onMove(perform: moveMilestones)
            } header: {
                Text(String(localized: "Milestones"))
            } footer: {
                if !datesFollowTimelineOrder {
                    Text(String(localized: "Milestone dates must follow the timeline order."))
                        .foregroundStyle(.red)
                } else {
                    Text(String(localized: "Reorder milestones as needed. Completion stays synchronized with task progress."))
                }
            }

            Section {
                Button(action: addMilestone) {
                    Label(String(localized: "Add Milestone"), systemImage: "plus.circle.fill")
                        .foregroundStyle(task.type.tint)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PlanoraBackground())
        .navigationTitle(String(localized: "Edit Timeline"))
        .planoraDetailNavigationBar()
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save"), action: saveTimeline)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
    }

    private func addMilestone() {
        let fallbackDate = milestones.last?.targetDate
            ?? task.deadline
            ?? Date()
        let clampedDate = min(max(fallbackDate, allowedDateRange.lowerBound), allowedDateRange.upperBound)

        milestones.append(
            AcademicMilestone(
                title: String(localized: "New Milestone"),
                targetDate: task.hasDeadline ? clampedDate : nil
            )
        )
    }

    private func deleteMilestones(at offsets: IndexSet) {
        guard milestones.count - offsets.count > 0 else { return }
        milestones.remove(atOffsets: offsets)
    }

    private func moveMilestones(from source: IndexSet, to destination: Int) {
        milestones.move(fromOffsets: source, toOffset: destination)
    }

    private func saveTimeline() {
        guard canSave else { return }

        let completedCount = milestones.filter(\.isCompleted).count
        let cleanedMilestones = milestones.enumerated().map { index, milestone in
            var cleaned = milestone
            cleaned.title = milestone.title.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned.isCompleted = index < completedCount
            return cleaned
        }

        task.replaceTimeline(with: cleanedMilestones)
        PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
        dismiss()
    }
}

private struct MilestoneEditorRow: View {
    @Binding var milestone: AcademicMilestone
    let allowedDateRange: ClosedRange<Date>
    let fallbackDate: Date

    private var hasTargetDate: Binding<Bool> {
        Binding(
            get: { milestone.targetDate != nil },
            set: { hasDate in
                milestone.targetDate = hasDate ? clampedFallbackDate : nil
            }
        )
    }

    private var targetDate: Binding<Date> {
        Binding(
            get: { milestone.targetDate ?? clampedFallbackDate },
            set: { milestone.targetDate = $0 }
        )
    }

    private var clampedFallbackDate: Date {
        min(max(fallbackDate, allowedDateRange.lowerBound), allowedDateRange.upperBound)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: milestone.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(milestone.isCompleted ? Color.planoraGreen : .secondary)

                TextField(String(localized: "Milestone Name"), text: $milestone.title)
                    .font(.headline)
            }

            Toggle(String(localized: "Target Date"), isOn: hasTargetDate)
                .tint(Color.planoraDeepGreen)

            if milestone.targetDate != nil {
                DatePicker(
                    String(localized: "Date"),
                    selection: targetDate,
                    in: allowedDateRange,
                    displayedComponents: .date
                )
            }
        }
        .padding(.vertical, 6)
    }
}

struct PriorityPill: View {
    let priority: TaskPriority

    var body: some View {
        Label(priority.title, systemImage: priority.symbol)
            .font(.caption.weight(.bold))
            .foregroundStyle(priority.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(priority.tint.opacity(0.12), in: Capsule())
    }
}

private struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color
    var showsChevron = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.planoraInk)

            Spacer(minLength: 12)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct EditTaskView: View {
    @Bindable var store: PlanoraStore
    @Bindable var task: PlanoraTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTask.createdDate) private var allTasks: [PlanoraTask]
    @State private var title: String
    @State private var selectedSubject: String
    @State private var selectedType: TaskType
    @State private var hasDeadline: Bool
    @State private var deadline: Date
    @State private var hasPlannedDate: Bool
    @State private var plannedDate: Date
    @State private var priority: TaskPriority
    @State private var tracksProgress: Bool
    @State private var progressKind: ProgressKind
    @State private var percentageProgress: Double
    @State private var stageName: String
    @State private var notes: String
    @State private var reminders: [TaskReminder]
    @State private var recurrenceRule: TaskRecurrenceRule?
    @State private var isShowingSeriesScope = false

    init(store: PlanoraStore, task: PlanoraTask) {
        self.store = store
        self.task = task
        _title = State(initialValue: task.title)
        _selectedSubject = State(initialValue: task.subject)
        _selectedType = State(initialValue: task.type)
        _hasDeadline = State(initialValue: task.hasDeadline)
        _deadline = State(initialValue: task.deadline ?? Date())
        _hasPlannedDate = State(initialValue: task.plannedDate != nil)
        _plannedDate = State(initialValue: task.plannedDate ?? Date())
        _priority = State(initialValue: task.priority)
        _tracksProgress = State(initialValue: task.tracksProgress)
        _progressKind = State(initialValue: task.progressState.kind)
        _percentageProgress = State(initialValue: task.progressState.percentageValue ?? 0)
        _stageName = State(initialValue: task.progressState.stageValue ?? task.type.defaultStage)
        _notes = State(initialValue: task.notes)
        _reminders = State(initialValue: task.reminders)
        _recurrenceRule = State(initialValue: task.recurrenceRule)
    }

    private var typeOptions: [TaskType] {
        let available = TaskType.availableTypes(for: store.curriculum, selectedSubjects: store.selectedSubjectTitles)
        return available.contains(selectedType) ? available : [selectedType] + available
    }

    private var subjectOptions: [String] {
        let available = selectedType.subjectOptions(
            for: store.curriculum,
            selectedSubjects: store.selectedSubjectTitles,
            selectedExtraLearning: store.selectedExtraLearningTitles
        )
        return available.contains(selectedSubject) ? available : [selectedSubject] + available
    }

    private var stageOptions: [String] {
        if selectedType == task.type,
           task.progressState.kind == .stage,
           !task.timeline.isEmpty {
            return task.timeline.map(\.title)
        }

        return selectedType.stageOptions
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !selectedSubject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        Form {
            Section(String(localized: "Details")) {
                TextField(String(localized: "Title"), text: $title)

                Picker(String(localized: "Type"), selection: $selectedType) {
                    ForEach(typeOptions) { type in
                        Label(type.title, systemImage: type.symbol).tag(type)
                    }
                }

                Picker(String(localized: "Subject"), selection: $selectedSubject) {
                    ForEach(subjectOptions, id: \.self) { subject in
                        Text(PlanoraFormat.subjectDisplayName(subject)).tag(subject)
                    }
                }
            }

            Section(String(localized: "Schedule")) {
                Toggle(String(localized: "Deadline"), isOn: $hasDeadline)
                    .tint(selectedType.tint)
                    .disabled(task.isRecurring || recurrenceRule != nil)

                if hasDeadline {
                    DatePicker(String(localized: "Date"), selection: $deadline, displayedComponents: .date)
                }

                Toggle(String(localized: "Planned Date"), isOn: $hasPlannedDate)
                    .tint(selectedType.tint)

                if hasPlannedDate {
                    DatePicker(String(localized: "Plan For"), selection: $plannedDate, displayedComponents: .date)
                }

                Picker(String(localized: "Priority"), selection: $priority) {
                    ForEach(TaskPriority.allCases) { priority in
                        Label(priority.title, systemImage: priority.symbol).tag(priority)
                    }
                }

                NavigationLink {
                    ReminderDraftEditorView(
                        reminders: $reminders,
                        deadline: hasDeadline ? deadline : nil,
                        tint: selectedType.tint
                    )
                } label: {
                    HStack {
                        Label(String(localized: "Reminders"), systemImage: "bell.badge")
                        Spacer()
                        Text(reminders.isEmpty ? String(localized: "Not Set") : PlanoraLocalization.format(String(localized: "reminder_count_format"), reminders.count))
                            .foregroundStyle(.secondary)
                    }
                }

                if task.isRecurring {
                    LabeledContent(String(localized: "Repeat"), value: task.recurrenceSummary)
                } else {
                    NavigationLink {
                        RecurrenceDraftEditorView(
                            rule: $recurrenceRule,
                            startDate: deadline,
                            tint: selectedType.tint
                        )
                    } label: {
                        HStack {
                            Label(String(localized: "Repeat"), systemImage: "repeat")
                            Spacer()
                            Text(recurrenceRule?.summary ?? String(localized: "Does Not Repeat"))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section(String(localized: "Learning Progress")) {
                Toggle(String(localized: "Track Progress"), isOn: $tracksProgress)
                    .tint(selectedType.tint)

                if tracksProgress {
                    Picker(String(localized: "Progress Type"), selection: $progressKind) {
                        ForEach(ProgressKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if progressKind == .percentage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(PlanoraFormat.percent(percentageProgress))
                                .font(.headline.weight(.bold))
                                .foregroundStyle(selectedType.tint)
                            Slider(value: $percentageProgress, in: 0...1, step: 0.05)
                                .tint(selectedType.tint)
                        }
                    } else {
                        Picker(String(localized: "Stage"), selection: $stageName) {
                            ForEach(stageOptions, id: \.self) { stage in
                                Text(stage).tag(stage)
                            }
                        }
                    }
                }
            }

            Section(String(localized: "Notes")) {
                TextField(String(localized: "Notes"), text: $notes, axis: .vertical)
                    .lineLimit(3...7)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PlanoraBackground())
        .navigationTitle(String(localized: "Edit Task"))
        .planoraDetailNavigationBar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save Changes")) {
                    requestSave()
                }
                .fontWeight(.semibold)
                .disabled(!canSave)
            }
        }
        .onChange(of: selectedType) { _, newType in
            let newSubjects = newType.subjectOptions(
                for: store.curriculum,
                selectedSubjects: store.selectedSubjectTitles,
                selectedExtraLearning: store.selectedExtraLearningTitles
            )

            if !newSubjects.contains(selectedSubject), let firstSubject = newSubjects.first {
                selectedSubject = firstSubject
            }

            if progressKind == .stage, !stageOptions.contains(stageName) {
                stageName = newType.defaultStage
            }
        }
        .onChange(of: recurrenceRule) { _, newRule in
            if newRule != nil { hasDeadline = true }
        }
        .confirmationDialog(
            String(localized: "Apply to Repeating Task"),
            isPresented: $isShowingSeriesScope,
            titleVisibility: .visible
        ) {
            Button(String(localized: "This Occurrence Only")) { saveChanges(scope: .occurrence) }
            Button(String(localized: "This and Future Occurrences")) { saveChanges(scope: .future) }
            Button(String(localized: "Entire Series")) { saveChanges(scope: .entireSeries) }
            Button(String(localized: "Cancel"), role: .cancel) {}
        }
    }

    private func requestSave() {
        guard canSave else { return }
        if task.isRecurring {
            isShowingSeriesScope = true
        } else {
            saveChanges(scope: .occurrence)
        }
    }

    private func saveChanges(scope: RecurrenceEditScope) {
        guard canSave else { return }

        let originalDeadline = task.deadline
        let targets = seriesTargets(for: scope)
        let deadlineShift = deadline.timeIntervalSince(originalDeadline ?? deadline)

        if scope == .future {
            RecurringTaskEngine.splitFutureSeries(tasks: targets, from: task)
        }

        applyChanges(to: task, deadline: hasDeadline ? deadline : nil, preservesProgress: false)

        for target in targets where target.id != task.id {
            let shiftedDeadline = target.deadline.map { $0.addingTimeInterval(deadlineShift) }
            applyChanges(to: target, deadline: hasDeadline ? shiftedDeadline : nil, preservesProgress: true)
        }

        var createdTasks: [PlanoraTask] = []
        if !task.isRecurring, let recurrenceRule {
            task.recurrenceRule = recurrenceRule
            task.recurrenceSeriesID = UUID()
            task.recurrenceOccurrenceDate = task.deadline
            createdTasks = RecurringTaskEngine.materializeSeries(from: task, in: modelContext)
        }

        PlanoraTaskPersistence.saveAndReconcile(
            fallbackTasks: createdTasks.isEmpty ? allTasks : allTasks + createdTasks,
            in: modelContext
        )
        dismiss()
    }

    private func seriesTargets(for scope: RecurrenceEditScope) -> [PlanoraTask] {
        guard let seriesID = task.recurrenceSeriesID else { return [task] }
        let series = allTasks.filter { $0.recurrenceSeriesID == seriesID }
        switch scope {
        case .occurrence:
            return [task]
        case .future:
            return series.filter { $0.recurrenceSequence >= task.recurrenceSequence }
        case .entireSeries:
            return series
        }
    }

    private func applyChanges(to target: PlanoraTask, deadline targetDeadline: Date?, preservesProgress: Bool) {

        let originalType = target.type
        let originalProgressKind = target.progressState.kind
        let originalStageName = target.stageName
        let wasCompleted = target.isCompleted

        target.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        target.subject = selectedSubject
        target.type = selectedType
        target.setDeadline(targetDeadline, enabled: hasDeadline)
        if target.id == task.id {
            target.setPlannedDate(hasPlannedDate ? plannedDate : nil)
        } else if hasPlannedDate {
            target.setPlannedDate(targetDeadline.map {
                $0.addingTimeInterval(plannedDate.timeIntervalSince(deadline))
            })
        } else {
            target.setPlannedDate(nil)
        }
        if target.isRecurring {
            target.recurrenceOccurrenceDate = targetDeadline
        }
        target.priority = priority
        target.tracksProgress = tracksProgress
        if !preservesProgress {
            target.progressState = progressKind == .percentage
                ? .percentage(percentageProgress)
                : .stage(stageName.isEmpty ? selectedType.defaultStage : stageName)
        }
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let targetReminders = preservesProgress
            ? reminders.filter(\.isRelativeToDeadline)
            : reminders
        target.replaceReminders(
            with: hasDeadline ? targetReminders : targetReminders.filter { !$0.isRelativeToDeadline }
        )

        if !preservesProgress, tracksProgress, progressKind == .stage {
            let shouldPreserveCompletion = originalType == selectedType && originalProgressKind == .stage
            let selectedStage = stageName.isEmpty ? selectedType.defaultStage : stageName

            if !shouldPreserveCompletion {
                target.rebuildTimeline(preservingCompletion: false)
            } else {
                target.ensureTimeline()
            }

            if wasCompleted,
               shouldPreserveCompletion,
               selectedStage == originalStageName {
                target.setCompleted(true)
            } else {
                target.setCurrentStage(selectedStage)
            }
            target.clampTimelineDatesToDeadline()
        } else if !preservesProgress {
            target.timelineData = nil
        }
    }
}
