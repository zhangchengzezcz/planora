import SwiftData
import SwiftUI

#if os(macOS)
struct MacTaskWorkspaceView: View {
    let store: PlanoraStore
    let searchText: String
    @Binding var selection: PlanoraTask.ID?
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var source: MacTaskSource = .all
    @State private var status: MacTaskStatus = .active
    @State private var selectedSubject = ""
    @State private var tableSelection = Set<PlanoraTask.ID>()
    @State private var isShowingBulkActions = false

    private var subjects: [String] {
        Array(Set(tasks.map(\.subject).filter { !$0.isEmpty })).sorted()
    }

    private var filteredTasks: [PlanoraTask] {
        tasks.filter { task in
            let statusMatch: Bool
            switch status {
            case .active: statusMatch = !task.isCompleted && !task.isArchived && !task.isDeleted
            case .completed: statusMatch = task.isCompleted && !task.isArchived && !task.isDeleted
            case .archived: statusMatch = task.isArchived && !task.isDeleted
            case .deleted: statusMatch = task.isDeleted
            }

            let sourceMatch: Bool
            switch source {
            case .all: sourceMatch = true
            case .personal: sourceMatch = !task.isManageBacTask
            case .manageBac: sourceMatch = task.isManageBacTask
            case .subject: sourceMatch = selectedSubject.isEmpty || task.subject == selectedSubject
            }

            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let searchMatch = query.isEmpty
                || task.title.localizedCaseInsensitiveContains(query)
                || task.subject.localizedCaseInsensitiveContains(query)
                || task.notes.localizedCaseInsensitiveContains(query)
            return statusMatch && sourceMatch && searchMatch
        }
        .planoraSorted {
            PlanoraTaskOrdering.areInListOrder($0, $1, sortOrder: store.taskDisplaySettings.sortOrder)
        }
    }

    private var selectedTask: PlanoraTask? {
        guard let selection else { return nil }
        return tasks.first { $0.id == selection }
    }

    var body: some View {
        let visibleTasks = filteredTasks

        VStack(spacing: 0) {
            filters(taskCount: visibleTasks.count)
            Divider()

            if visibleTasks.isEmpty {
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Tasks Yet"),
                        systemImage: "checklist"
                    )
                } else {
                    ContentUnavailableView.search(text: searchText)
                }
            } else {
                Table(visibleTasks, selection: $tableSelection) {
                    TableColumn(String(localized: "Task")) { task in
                        HStack(spacing: 8) {
                            TaskCompletionButton(task: task)
                            Image(systemName: task.type.symbol)
                                .foregroundStyle(.secondary)
                            Text(task.title).lineLimit(1)
                        }
                    }
                    .width(min: 220, ideal: 330)

                    TableColumn(String(localized: "Subject")) { task in
                        Text(PlanoraFormat.subjectDisplayName(task.subject)).lineLimit(1)
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn(String(localized: "Planned Date")) { task in
                        Text(task.plannedDate?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    }
                    .width(110)

                    TableColumn(String(localized: "Deadline")) { task in
                        Text(task.deadline?.formatted(date: .abbreviated, time: .omitted) ?? "—")
                    }
                    .width(110)

                    TableColumn(String(localized: "Priority")) { task in
                        Label(task.priority.title, systemImage: task.priority.symbol)
                    }
                    .width(90)
                }
                .contextMenu(forSelectionType: PlanoraTask.ID.self) { ids in
                    if let id = ids.first, let task = tasks.first(where: { $0.id == id }) {
                        if task.isDeleted {
                            Button(String(localized: "Restore Task"), systemImage: "arrow.uturn.backward") {
                                PlanoraTaskOperations.restoreFromRecentlyDeleted([task], modelContext: modelContext)
                            }
                            Button(String(localized: "Delete Permanently"), systemImage: "trash", role: .destructive) {
                                PlanoraTaskOperations.permanentlyDelete([task], allTasks: tasks, modelContext: modelContext)
                            }
                        } else {
                        Button(
                            task.isPinned ? String(localized: "Unpin Task") : String(localized: "Pin Task"),
                            systemImage: task.isPinned ? "pin.slash" : "pin"
                        ) {
                            task.isPinned.toggle()
                            PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                        }
                        Divider()
                        Button(task.isCompleted ? String(localized: "Mark Incomplete") : String(localized: "Mark Complete")) {
                            task.setCompleted(!task.isCompleted)
                            PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                        }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: tableSelection) { _, ids in
            selection = ids.count == 1 ? ids.first : nil
        }
        .onChange(of: selection) { _, id in
            guard let id else { return }
            let desired = Set([id])
            if tableSelection != desired { tableSelection = desired }
        }
        .sheet(isPresented: $isShowingBulkActions) {
            BulkTaskActionsView(
                store: store,
                selectedTasks: tasks.filter { tableSelection.contains($0.id) },
                allTasks: tasks,
                onFinish: {
                    tableSelection.removeAll()
                    selection = nil
                }
            )
            .frame(minWidth: 520, idealWidth: 600, minHeight: 500, idealHeight: 620)
        }
        .inspector(isPresented: Binding(
            get: { selectedTask != nil },
            set: { if !$0 { selection = nil } }
        )) {
            if let selectedTask {
                MacTaskInspector(store: store, task: selectedTask)
                    .inspectorColumnWidth(min: 300, ideal: 340, max: 430)
            }
        }
    }

    private func filters(taskCount: Int) -> some View {
        HStack(spacing: 12) {
            Picker(String(localized: "Source"), selection: $source) {
                ForEach(MacTaskSource.allCases) { value in
                    Label(value.title, systemImage: value.symbol).tag(value)
                }
            }
            .frame(width: 180)
            .buttonStyle(.glass)

            Text(String(localized: "Status"))
            MacLiquidGlassStatusPicker(selection: $status)
                .frame(width: 330, height: 34)

            if source == .subject {
                Picker(String(localized: "Subject"), selection: $selectedSubject) {
                    Text(String(localized: "All Subjects")).tag("")
                    ForEach(subjects, id: \.self) { Text(PlanoraFormat.subjectDisplayName($0)).tag($0) }
                }
                .frame(width: 210)
                .buttonStyle(.glass)
            }

            Spacer()
            if !tableSelection.isEmpty && status != .deleted {
                Button(String(localized: "Actions"), systemImage: "ellipsis.circle") {
                    isShowingBulkActions = true
                }
            }
            Text(PlanoraLocalization.format(String(localized: "task_count_format"), taskCount))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
    }
}

private struct MacLiquidGlassStatusPicker: View {
    @Binding var selection: MacTaskStatus

    var body: some View {
        GeometryReader { geometry in
            Picker(String(localized: "Status"), selection: $selection) {
                ForEach(MacTaskStatus.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.large)
            .accessibilityLabel(String(localized: "Status"))
            .simultaneousGesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { gesture in
                        let values = MacTaskStatus.allCases
                        let segmentWidth = geometry.size.width / CGFloat(values.count)
                        let index = min(max(Int(gesture.location.x / segmentWidth), 0), values.count - 1)
                        if selection != values[index] {
                            withAnimation(.snappy) { selection = values[index] }
                        }
                    }
            )
        }
    }
}

private enum MacTaskSource: String, CaseIterable, Identifiable {
    case all, personal, manageBac, subject
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: String(localized: "All Tasks")
        case .personal: String(localized: "Personal")
        case .manageBac: "ManageBac"
        case .subject: String(localized: "Current Subject")
        }
    }
    var symbol: String {
        switch self {
        case .all: "tray.full"
        case .personal: "person"
        case .manageBac: "building.columns"
        case .subject: "book"
        }
    }
}

private enum MacTaskStatus: String, CaseIterable, Identifiable {
    case active, completed, archived, deleted
    var id: String { rawValue }
    var title: String {
        switch self {
        case .active: String(localized: "Active")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Archived")
        case .deleted: String(localized: "Recently Deleted")
        }
    }
}

private struct MacTaskInspector: View {
    let store: PlanoraStore
    @Bindable var task: PlanoraTask
    @Environment(\.modelContext) private var modelContext
    @State private var newSubtaskTitle = ""
    @State private var newLinkTitle = ""
    @State private var newLinkURL = ""
    @State private var isConfirmingIncompleteSubtasks = false

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Title"), text: $task.title)
                Picker(String(localized: "Subject"), selection: $task.subject) {
                    ForEach(Array(Set(store.selectedSubjectTitles + [task.subject])).sorted(), id: \.self) {
                        Text(PlanoraFormat.subjectDisplayName($0)).tag($0)
                    }
                }
                Picker(String(localized: "Type"), selection: Binding(
                    get: { task.type },
                    set: { task.type = $0 }
                )) {
                    ForEach(TaskType.allCases) { Text($0.title).tag($0) }
                }
                Picker(String(localized: "Priority"), selection: Binding(
                    get: { task.priority },
                    set: { task.priority = $0 }
                )) {
                    ForEach(TaskPriority.allCases) { Text($0.title).tag($0) }
                }
            }

            Section(String(localized: "Schedule")) {
                Toggle(String(localized: "Deadline"), isOn: Binding(
                    get: { task.hasDeadline },
                    set: { task.setDeadline($0 ? (task.deadline ?? Date()) : nil, enabled: $0) }
                ))
                if task.hasDeadline {
                    DatePicker(String(localized: "Deadline"), selection: Binding(
                        get: { task.deadline ?? Date() },
                        set: { task.setDeadline($0, enabled: true) }
                    ), displayedComponents: .date)
                }
                Toggle(String(localized: "Planned Date"), isOn: Binding(
                    get: { task.plannedDate != nil },
                    set: { task.setPlannedDate($0 ? (task.plannedDate ?? Date()) : nil) }
                ))
                if task.plannedDate != nil {
                    DatePicker(String(localized: "Planned Date"), selection: Binding(
                        get: { task.plannedDate ?? Date() },
                        set: { task.setPlannedDate($0) }
                    ), displayedComponents: .date)
                }
                Picker(String(localized: "Estimated Time"), selection: $task.estimatedMinutes) {
                    ForEach(PlanoraDurationFormatter.options, id: \.self) { minutes in
                        Text(PlanoraDurationFormatter.text(minutes: minutes)).tag(minutes)
                    }
                }
                if let completedDate = task.completedDate {
                    LabeledContent(String(localized: "Completed"), value: completedDate.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section(String(localized: "Notes")) {
                TextEditor(text: $task.notes).frame(minHeight: 90)
            }

            Section(String(localized: "Subtasks")) {
                if !task.subtasks.isEmpty {
                    Toggle(String(localized: "Calculate progress from subtasks"), isOn: $task.usesSubtasksForProgress)
                }
                ForEach(task.subtasks.sorted { $0.sortOrder < $1.sortOrder }) { subtask in
                    MacSubtaskFormRow(task: task, subtask: subtask)
                }
                HStack {
                    TextField(String(localized: "Subtask Title"), text: $newSubtaskTitle)
                    Button(String(localized: "Add"), systemImage: "plus") { addSubtask() }
                        .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section(String(localized: "Links and Resources")) {
                ForEach(task.resourceLinks.sorted { $0.createdDate < $1.createdDate }) { resource in
                    HStack {
                        if let url = resource.url {
                            Link(resource.title, destination: url)
                        } else {
                            Text(resource.title)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            task.resourceLinks.removeAll { $0.id == resource.id }
                            modelContext.delete(resource)
                        } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                    }
                }
                TextField(String(localized: "Link Title"), text: $newLinkTitle)
                TextField(String(localized: "URL"), text: $newLinkURL)
                Button(String(localized: "Add Link"), systemImage: "link.badge.plus") { addLink() }
                    .disabled(validLinkURL == nil)
            }

            Section {
                if task.isDeleted {
                    Button(String(localized: "Restore Task"), systemImage: "arrow.uturn.backward") {
                        PlanoraTaskOperations.restoreFromRecentlyDeleted([task], modelContext: modelContext)
                    }
                    Button(String(localized: "Delete Permanently"), systemImage: "trash", role: .destructive) {
                        let allTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? [task]
                        PlanoraTaskOperations.permanentlyDelete([task], allTasks: allTasks, modelContext: modelContext)
                    }
                } else {
                Button(
                    task.isPinned ? String(localized: "Unpin Task") : String(localized: "Pin Task"),
                    systemImage: task.isPinned ? "pin.slash" : "pin"
                ) {
                    task.isPinned.toggle()
                    PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                }
                Button(task.isCompleted ? String(localized: "Mark Incomplete") : String(localized: "Mark Complete")) {
                    if !task.isCompleted && task.subtasks.contains(where: { !$0.isCompleted }) {
                        isConfirmingIncompleteSubtasks = true
                    } else {
                        toggleCompletion()
                    }
                }
                Button(task.isArchived ? String(localized: "Restore from Archive") : String(localized: "Archive")) {
                    task.archivedDate = task.isArchived ? nil : Date()
                    PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                }
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onDisappear { PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext) }
        .confirmationDialog(
            String(localized: "Some subtasks are not finished."),
            isPresented: $isConfirmingIncompleteSubtasks
        ) {
            Button(String(localized: "Complete Task and Subtasks")) { toggleCompletion() }
            Button(String(localized: "Cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "Completing this task will also mark every subtask as complete."))
        }
    }

    private var validLinkURL: URL? {
        guard let url = URL(string: newLinkURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }

    private func addSubtask() {
        let title = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let subtask = PlanoraSubtask(title: title, sortOrder: task.subtasks.count, task: task)
        task.subtasks.append(subtask)
        modelContext.insert(subtask)
        newSubtaskTitle = ""
        PlanoraTaskPersistence.save(modelContext)
    }

    private func addLink() {
        guard let url = validLinkURL else { return }
        let title = newLinkTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let resource = PlanoraResourceLink(
            title: title.isEmpty ? (url.host ?? String(localized: "Resource")) : title,
            urlString: url.absoluteString,
            task: task
        )
        task.resourceLinks.append(resource)
        modelContext.insert(resource)
        newLinkTitle = ""
        newLinkURL = ""
        PlanoraTaskPersistence.save(modelContext)
    }

    private func toggleCompletion() {
        task.setCompleted(!task.isCompleted)
        PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
    }
}

private struct MacSubtaskFormRow: View {
    @Bindable var task: PlanoraTask
    @Bindable var subtask: PlanoraSubtask
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: $subtask.isCompleted).labelsHidden()
                TextField(String(localized: "Subtask Title"), text: $subtask.title)
                Button(role: .destructive) {
                    task.subtasks.removeAll { $0.id == subtask.id }
                    modelContext.delete(subtask)
                    PlanoraTaskPersistence.save(modelContext)
                } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
            }
            HStack {
                Toggle(String(localized: "Target Date"), isOn: Binding(
                    get: { subtask.targetDate != nil },
                    set: { subtask.targetDate = $0 ? (subtask.targetDate ?? Date()) : nil }
                ))
                if subtask.targetDate != nil {
                    DatePicker("", selection: Binding(
                        get: { subtask.targetDate ?? Date() },
                        set: { subtask.targetDate = $0 }
                    ), displayedComponents: .date)
                    .labelsHidden()
                }
                Picker(String(localized: "Estimated Time"), selection: $subtask.estimatedMinutes) {
                    ForEach(PlanoraDurationFormatter.options, id: \.self) { minutes in
                        Text(PlanoraDurationFormatter.text(minutes: minutes)).tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(width: 130)
            }
            .controlSize(.small)
        }
        .onChange(of: subtask.isCompleted) { _, _ in
            if task.usesSubtasksForProgress, !task.subtasks.isEmpty {
                task.percentageProgress = Double(task.subtasks.filter(\.isCompleted).count) / Double(task.subtasks.count)
            }
            PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
        }
    }
}
#endif
