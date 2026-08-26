import SwiftData
import SwiftUI

#if os(macOS)
struct MacTaskWorkspaceView: View {
    let store: PlanoraStore
    let searchText: String
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var selection: PlanoraTask.ID?
    @State private var source: MacTaskSource = .all
    @State private var status: MacTaskStatus = .active
    @State private var selectedSubject = ""

    private var subjects: [String] {
        Array(Set(tasks.map(\.subject).filter { !$0.isEmpty })).sorted()
    }

    private var filteredTasks: [PlanoraTask] {
        tasks.filter { task in
            let statusMatch: Bool
            switch status {
            case .active: statusMatch = !task.isCompleted && !task.isArchived
            case .completed: statusMatch = task.isCompleted && !task.isArchived
            case .archived: statusMatch = task.isArchived
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
                Table(visibleTasks, selection: $selection) {
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
                        Button(task.isCompleted ? String(localized: "Mark Incomplete") : String(localized: "Mark Complete")) {
                            task.setCompleted(!task.isCompleted)
                            PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
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

            Picker(String(localized: "Status"), selection: $status) {
                ForEach(MacTaskStatus.allCases) { value in
                    Text(value.title).tag(value)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 330)

            if source == .subject {
                Picker(String(localized: "Subject"), selection: $selectedSubject) {
                    Text(String(localized: "All Subjects")).tag("")
                    ForEach(subjects, id: \.self) { Text(PlanoraFormat.subjectDisplayName($0)).tag($0) }
                }
                .frame(width: 210)
            }

            Spacer()
            Text(PlanoraLocalization.format(String(localized: "task_count_format"), taskCount))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(12)
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
    case active, completed, archived
    var id: String { rawValue }
    var title: String {
        switch self {
        case .active: String(localized: "Active")
        case .completed: String(localized: "Completed")
        case .archived: String(localized: "Archived")
        }
    }
}

private struct MacTaskInspector: View {
    let store: PlanoraStore
    @Bindable var task: PlanoraTask
    @Environment(\.modelContext) private var modelContext

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
            }

            Section(String(localized: "Notes")) {
                TextEditor(text: $task.notes).frame(minHeight: 90)
            }

            Section {
                Button(task.isCompleted ? String(localized: "Mark Incomplete") : String(localized: "Mark Complete")) {
                    task.setCompleted(!task.isCompleted)
                    PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.vertical, 8)
        .onDisappear { PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext) }
    }
}
#endif
