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
                        if task.remoteStatusRawValue == ManageBacRemoteTaskStatus.completed.rawValue {
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
                        Label(task.priority.title, systemImage: task.priority.symbol)
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
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .frame(minWidth: 620, idealWidth: 760, minHeight: 600, idealHeight: 800)
        }
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
                NavigationStack {
                    TaskDetailView(store: store, task: selectedTask)
                        .id(selectedTask.id)
                }
                .inspectorColumnWidth(min: 420, ideal: 500, max: 700)
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
            if let selectedTask {
                Button(String(localized: "Task Details"), systemImage: "doc.text") {
                    detailTask = selectedTask
                }
            }
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

#endif
