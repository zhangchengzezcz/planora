import SwiftData
import SwiftUI

private enum BulkTaskAction: String, CaseIterable, Identifiable {
    case complete
    case archive
    case subject
    case priority
    case plannedDate
    case delete

    var id: String { rawValue }

    var title: String {
        switch self {
        case .complete: String(localized: "Mark Complete")
        case .archive: String(localized: "Archive")
        case .subject: String(localized: "Change Subject")
        case .priority: String(localized: "Change Priority")
        case .plannedDate: String(localized: "Change Planned Date")
        case .delete: String(localized: "Delete")
        }
    }
}

struct BulkTaskActionsView: View {
    let store: PlanoraStore
    let selectedTasks: [PlanoraTask]
    let allTasks: [PlanoraTask]
    let onFinish: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var action: BulkTaskAction = .complete
    @State private var scopeIndex = 0
    @State private var subject = ""
    @State private var priority = TaskPriority.medium
    @State private var hasPlannedDate = true
    @State private var plannedDate = Date()
    @State private var isConfirmingDelete = false

    private var includesRecurringTask: Bool {
        selectedTasks.contains(where: \.isRecurring)
    }

    private var scope: RecurrenceEditScope {
        switch scopeIndex {
        case 1: .future
        case 2: .entireSeries
        default: .occurrence
        }
    }

    private var subjects: [String] {
        Array(Set(store.selectedSubjectTitles + selectedTasks.map(\.subject)))
            .filter { !$0.isEmpty }
            .sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent(
                        String(localized: "Selected Tasks"),
                        value: "\(selectedTasks.count)"
                    )

                    Picker(String(localized: "Action"), selection: $action) {
                        ForEach(BulkTaskAction.allCases) { value in
                            Text(value.title).tag(value)
                        }
                    }
                }

                if includesRecurringTask {
                    Section(String(localized: "Repeat Scope")) {
                        Picker(String(localized: "Repeat Scope"), selection: $scopeIndex) {
                            Text(String(localized: "This Occurrence")).tag(0)
                            Text(String(localized: "This and Future")).tag(1)
                            Text(String(localized: "Entire Series")).tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                actionOptions
            }
            .navigationTitle(String(localized: "Bulk Actions"))
            .planoraDetailNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action == .delete ? String(localized: "Delete") : String(localized: "Apply")) {
                        if action == .delete {
                            isConfirmingDelete = true
                        } else {
                            apply()
                        }
                    }
                    .tint(action == .delete ? .red : .accentColor)
                    .disabled(action == .subject && subject.isEmpty)
                }
            }
            .onAppear {
                subject = selectedTasks.first?.subject ?? subjects.first ?? ""
                priority = selectedTasks.first?.priority ?? .medium
                if let existingDate = selectedTasks.compactMap(\.plannedDate).first {
                    plannedDate = existingDate
                }
            }
            .alert(String(localized: "Delete Selected Tasks?"), isPresented: $isConfirmingDelete) {
                Button(String(localized: "Delete"), role: .destructive) { apply() }
                Button(String(localized: "Cancel"), role: .cancel) {}
            } message: {
                Text(String(localized: "This action can be undone immediately after deletion."))
            }
        }
    }

    @ViewBuilder
    private var actionOptions: some View {
        switch action {
        case .subject:
            Section(String(localized: "Subject")) {
                Picker(String(localized: "Subject"), selection: $subject) {
                    ForEach(subjects, id: \.self) { value in
                        Text(PlanoraFormat.subjectDisplayName(value)).tag(value)
                    }
                }
            }
        case .priority:
            Section(String(localized: "Priority")) {
                Picker(String(localized: "Priority"), selection: $priority) {
                    ForEach(TaskPriority.allCases) { value in
                        Label(value.title, systemImage: value.symbol).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }
        case .plannedDate:
            Section(String(localized: "Planned Date")) {
                Toggle(String(localized: "Set Planned Date"), isOn: $hasPlannedDate)
                if hasPlannedDate {
                    DatePicker(
                        String(localized: "Planned Date"),
                        selection: $plannedDate,
                        displayedComponents: .date
                    )
                }
            }
        case .complete:
            Section {
                Text(String(localized: "Completing a task also completes its remaining subtasks."))
                    .foregroundStyle(.secondary)
            }
        case .archive:
            Section {
                Text(String(localized: "Archived tasks remain available in task history."))
                    .foregroundStyle(.secondary)
            }
        case .delete:
            Section {
                Text(String(localized: "Deleted tasks remain in Recently Deleted until permanently removed."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func apply() {
        let targets = PlanoraTaskOperations.targets(
            for: selectedTasks,
            scope: scope,
            in: allTasks
        )

        switch action {
        case .complete:
            targets.forEach { $0.setCompleted(true) }
            PlanoraTaskPersistence.saveAndReconcile(fallbackTasks: allTasks, in: modelContext)
        case .archive:
            targets.forEach { $0.archivedDate = Date() }
            PlanoraTaskPersistence.saveAndReconcile(fallbackTasks: allTasks, in: modelContext)
        case .subject:
            targets.forEach { $0.subject = subject }
            PlanoraTaskPersistence.save(modelContext)
        case .priority:
            targets.forEach { $0.priority = priority }
            PlanoraTaskPersistence.save(modelContext)
        case .plannedDate:
            targets.forEach { $0.setPlannedDate(hasPlannedDate ? plannedDate : nil) }
            PlanoraTaskPersistence.save(modelContext)
        case .delete:
            PlanoraTaskOperations.delete(
                selectedTasks,
                scope: scope,
                allTasks: allTasks,
                modelContext: modelContext,
                store: store
            )
        }

        onFinish()
        dismiss()
    }
}
