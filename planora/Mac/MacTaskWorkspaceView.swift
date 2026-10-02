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
    @State private var isShowingImport = false
    @State private var detailTask: PlanoraTask?
    @State private var taskPendingCompletion: PlanoraTask?

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
                Group {
                    if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        ContentUnavailableView(
                            String(localized: "No Tasks Yet"),
                            systemImage: "checklist"
                        )
                    } else {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(visibleTasks, selection: $tableSelection) {
                    TableColumn(String(localized: "Task")) { task in
                        HStack(spacing: 8) {
                            Image(systemName: task.type.symbol)
                                .foregroundStyle(.secondary)
                            Text(task.title).lineLimit(1)
                        }
                    }
                    .width(min: 220, ideal: 330)

                    TableColumn(String(localized: "ManageBac Result")) { task in
                        Text(task.manageBacAssessmentSummary ?? "—")
                            .font(.body.weight(.semibold))
                            .monospacedDigit()
                    }
                    .width(min: 110, ideal: 150)

                    TableColumn("ManageBac · " + String(localized: "Status")) { task in
                        if task.isManageBacCompleted {
                            Label(String(localized: "Completed"), systemImage: "checkmark.seal")
                                .foregroundStyle(Color.planoraDeepGreen)
                        } else {
                            Text("—").foregroundStyle(.secondary)
                        }
                    }
                    .width(min: 110, ideal: 140)

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
                        Label(task.priorityDisplayTitle, systemImage: task.displayPriority.symbol)
                    }
                    .width(90)
                }
                .contextMenu(forSelectionType: PlanoraTask.ID.self) { ids in
                    if let id = ids.first, let task = tasks.first(where: { $0.id == id }) {
                        Button(String(localized: "Task Details"), systemImage: "doc.text") {
                            detailTask = task
                        }
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
                            taskPendingCompletion = task
                        }
                        }
                    }
                } primaryAction: { ids in
                    if ids.count == 1, let id = ids.first {
                        detailTask = tasks.first { $0.id == id }
                    }
                }
                .frame(minWidth: 0, maxWidth: .infinity)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .taskCompletionConfirmation(task: $taskPendingCompletion)
        .sheet(item: $detailTask) { task in
            NavigationStack {
                TaskDetailView(store: store, task: task)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(String(localized: "Done")) { detailTask = nil }
                        }
                    }
            }
            .frame(minWidth: 380, idealWidth: 700, minHeight: 420, idealHeight: 720)
        }
        .onChange(of: tableSelection) { _, ids in
            selection = ids.count == 1 ? ids.first : nil
        }
        .onChange(of: selection) { _, id in
            guard let id else { return }
            if let task = tasks.first(where: { $0.id == id }),
               !filteredTasks.contains(where: { $0.id == id }) {
                source = .all
                selectedSubject = ""
                status = task.isDeleted ? .deleted : task.isArchived ? .archived : task.isCompleted ? .completed : .active
            }
            let desired = Set([id])
            if tableSelection != desired { tableSelection = desired }
        }
        .onAppear {
            if let selection { tableSelection = [selection] }
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
                NavigationStack {
                    TaskDetailView(store: store, task: selectedTask)
                        .id(selectedTask.id)
                }
                .inspectorColumnWidth(min: 300, ideal: 360, max: 520)
            }
        }
    }

    private func filters(taskCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
            Picker(String(localized: "Source"), selection: $source) {
                ForEach(MacTaskSource.allCases) { value in
                    Label(value.title, systemImage: value.symbol).tag(value)
                }
            }
            .frame(width: 180)
            .buttonStyle(.glass)

            Spacer(minLength: 0)
            Text(PlanoraLocalization.format(String(localized: "task_count_format"), taskCount))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            if source == .subject {
                Picker(String(localized: "Subject"), selection: $selectedSubject) {
                    Text(String(localized: "All Subjects")).tag("")
                    ForEach(subjects, id: \.self) { Text(PlanoraFormat.subjectDisplayName($0)).tag($0) }
                }
                .frame(maxWidth: 260)
                .buttonStyle(.glass)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    MacLiquidGlassStatusPicker(selection: $status)
                    taskActions
                }
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal) {
                        MacLiquidGlassStatusPicker(selection: $status)
                    }
                    .frame(height: 42)
                    taskActions
                }
            }
        }
        .padding(12)
    }

    private var taskActions: some View {
        HStack(spacing: 10) {
            Button(String(localized: "Import"), systemImage: "arrow.triangle.2.circlepath") {
                isShowingImport = true
            }
            .help(String(localized: "Connect or sync ManageBac"))
            if let selectedTask {
                Button(String(localized: "Task Details"), systemImage: "doc.text") {
                    detailTask = selectedTask
                }
                .help(String(localized: "Task Details"))
            }
            if !tableSelection.isEmpty && status != .deleted {
                Button(String(localized: "Actions"), systemImage: "ellipsis.circle") {
                    isShowingBulkActions = true
                }
                .help(String(localized: "Actions"))
            }
        }
        .labelStyle(.iconOnly)
        .sheet(isPresented: $isShowingImport) {
            NavigationStack {
                ManageBacSettingsView(store: store) { isShowingImport = false }
            }
            .frame(minWidth: 680, idealWidth: 760, minHeight: 600, idealHeight: 720)
        }
    }
}

private struct MacLiquidGlassStatusPicker: View {
    @Binding var selection: MacTaskStatus

    var body: some View {
        MacModePicker(selection: $selection, values: MacTaskStatus.allCases,
                      title: String(localized: "Status"),
                      label: { $0.title }, symbol: { _ in "circle" }, showsLabels: true)
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
    var tint: Color {
        switch self {
        case .active: .planoraBlue
        case .completed: .planoraGreen
        case .archived: .planoraAmber
        case .deleted: .pink
        }
    }
    var title: String {
        switch self {
        case .active: String(localized: "Active")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Archived")
        case .deleted: String(localized: "Recently Deleted")
        }
    }
}

#endif
