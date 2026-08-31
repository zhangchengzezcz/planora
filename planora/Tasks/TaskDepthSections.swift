import SwiftData
import SwiftUI

struct TaskSubtasksPanel: View {
    @Bindable var task: PlanoraTask
    @Environment(\.modelContext) private var modelContext
    @State private var isAdding = false
    @State private var newTitle = ""

    private var ordered: [PlanoraSubtask] {
        task.subtasks.sorted {
            if $0.sortOrder == $1.sortOrder { return $0.createdDate < $1.createdDate }
            return $0.sortOrder < $1.sortOrder
        }
    }

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(String(localized: "Subtasks"), systemImage: "checklist")
                        .font(.headline.weight(.bold))
                    Spacer()
                    if !ordered.isEmpty {
                        Text(PlanoraLocalization.format(String(localized: "subtask_progress_format"), completedCount, ordered.count))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Button { isAdding = true } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(String(localized: "Add Subtask"))
                }

                if ordered.isEmpty {
                    Text(String(localized: "Break this task into smaller actions."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Toggle(String(localized: "Calculate progress from subtasks"), isOn: Binding(
                        get: { task.usesSubtasksForProgress },
                        set: {
                            task.usesSubtasksForProgress = $0
                            save()
                        }
                    ))
                    .tint(task.type.tint)

                    ForEach(Array(ordered.enumerated()), id: \.element.id) { index, subtask in
                        if index > 0 { Divider() }
                        subtaskRow(subtask, index: index)
                    }
                }
            }
        }
        .alert(String(localized: "Add Subtask"), isPresented: $isAdding) {
            TextField(String(localized: "Subtask Title"), text: $newTitle)
            Button(String(localized: "Add")) { addSubtask() }
                .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            Button(String(localized: "Cancel"), role: .cancel) { newTitle = "" }
        }
    }

    private func subtaskRow(_ subtask: PlanoraSubtask, index: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                subtask.isCompleted.toggle()
                if task.usesSubtasksForProgress, !ordered.isEmpty {
                    task.percentageProgress = Double(completedCount) / Double(ordered.count)
                }
                save()
            } label: {
                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(subtask.isCompleted ? Color.planoraGreen : .secondary)
            }
            .buttonStyle(.plain)

            NavigationLink {
                SubtaskEditorView(subtask: subtask)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(subtask.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.planoraInk)
                        .strikethrough(subtask.isCompleted)
                    Text(metadata(for: subtask))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Menu {
                Button(String(localized: "Move Up"), systemImage: "arrow.up") { move(index, by: -1) }
                    .disabled(index == 0)
                Button(String(localized: "Move Down"), systemImage: "arrow.down") { move(index, by: 1) }
                    .disabled(index == ordered.count - 1)
                Divider()
                Button(String(localized: "Delete"), systemImage: "trash", role: .destructive) {
                    task.subtasks.removeAll { $0.id == subtask.id }
                    modelContext.delete(subtask)
                    normalizeOrder()
                    save()
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
        }
    }

    private var completedCount: Int { ordered.filter(\.isCompleted).count }

    private func metadata(for subtask: PlanoraSubtask) -> String {
        let values = [
            subtask.targetDate.map { PlanoraFormat.monthDay($0) },
            subtask.estimatedMinutes > 0 ? PlanoraDurationFormatter.text(minutes: subtask.estimatedMinutes) : nil
        ].compactMap { $0 }
        return values.isEmpty ? String(localized: "No target date") : values.joined(separator: " · ")
    }

    private func addSubtask() {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let subtask = PlanoraSubtask(title: title, sortOrder: ordered.count, task: task)
        task.subtasks.append(subtask)
        modelContext.insert(subtask)
        newTitle = ""
        save()
    }

    private func move(_ index: Int, by offset: Int) {
        let destination = index + offset
        guard ordered.indices.contains(index), ordered.indices.contains(destination) else { return }
        var values = ordered
        values.swapAt(index, destination)
        values.enumerated().forEach { $0.element.sortOrder = $0.offset }
        save()
    }

    private func normalizeOrder() {
        ordered.enumerated().forEach { $0.element.sortOrder = $0.offset }
    }

    private func save() {
        PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
    }
}

private struct SubtaskEditorView: View {
    @Bindable var subtask: PlanoraSubtask
    @Environment(\.modelContext) private var modelContext
    @State private var hasTargetDate: Bool

    init(subtask: PlanoraSubtask) {
        self.subtask = subtask
        _hasTargetDate = State(initialValue: subtask.targetDate != nil)
    }

    var body: some View {
        Form {
            Section(String(localized: "Subtask")) {
                TextField(String(localized: "Subtask Title"), text: $subtask.title)
                Toggle(String(localized: "Completed"), isOn: $subtask.isCompleted)
            }
            Section(String(localized: "Plan")) {
                Toggle(String(localized: "Target Date"), isOn: $hasTargetDate)
                if hasTargetDate {
                    DatePicker(String(localized: "Date"), selection: Binding(
                        get: { subtask.targetDate ?? Date() },
                        set: { subtask.targetDate = $0 }
                    ), displayedComponents: .date)
                }
                Picker(String(localized: "Estimated Time"), selection: $subtask.estimatedMinutes) {
                    ForEach(PlanoraDurationFormatter.options, id: \.self) { minutes in
                        Text(PlanoraDurationFormatter.text(minutes: minutes)).tag(minutes)
                    }
                }
            }
        }
        .navigationTitle(String(localized: "Edit Subtask"))
        .onChange(of: hasTargetDate) { _, enabled in
            subtask.targetDate = enabled ? (subtask.targetDate ?? Date()) : nil
        }
        .onDisappear {
            subtask.title = subtask.title.trimmingCharacters(in: .whitespacesAndNewlines)
            try? modelContext.save()
        }
    }
}

struct TaskResourcesPanel: View {
    @Bindable var task: PlanoraTask
    @Environment(\.modelContext) private var modelContext
    @State private var isAdding = false
    @State private var title = ""
    @State private var urlText = ""
    @State private var validationMessage: String?

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label(String(localized: "Links and Resources"), systemImage: "link")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Button { isAdding = true } label: { Image(systemName: "plus") }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(String(localized: "Add Link"))
                }

                if task.resourceLinks.isEmpty {
                    Text(String(localized: "Keep reference pages and document links with this task."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(task.resourceLinks.sorted { $0.createdDate < $1.createdDate }.enumerated()), id: \.element.id) { index, resource in
                        if index > 0 { Divider() }
                        HStack(spacing: 10) {
                            if let url = resource.url {
                                Link(destination: url) {
                                    Label(resource.title, systemImage: "link")
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else {
                                Label(resource.title, systemImage: "link.badge.plus")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Button(role: .destructive) {
                                task.resourceLinks.removeAll { $0.id == resource.id }
                                modelContext.delete(resource)
                                save()
                            } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                    }
                }

                if let validationMessage {
                    Text(validationMessage).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .alert(String(localized: "Add Link"), isPresented: $isAdding) {
            TextField(String(localized: "Link Title"), text: $title)
            TextField(String(localized: "URL"), text: $urlText)
            Button(String(localized: "Add")) { addLink() }
            Button(String(localized: "Cancel"), role: .cancel) { resetDraft() }
        } message: {
            Text(String(localized: "Use a complete http or https address."))
        }
    }

    private func addLink() {
        let value = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            validationMessage = String(localized: "Enter a valid web address.")
            return
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resource = PlanoraResourceLink(
            title: cleanTitle.isEmpty ? (url.host ?? String(localized: "Resource")) : cleanTitle,
            urlString: value,
            task: task
        )
        task.resourceLinks.append(resource)
        modelContext.insert(resource)
        validationMessage = nil
        resetDraft()
        save()
    }

    private func resetDraft() {
        title = ""
        urlText = ""
    }

    private func save() {
        PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
    }
}

enum PlanoraDurationFormatter {
    static let options = [0, 15, 30, 45, 60, 90, 120, 180, 240]

    static func text(minutes: Int) -> String {
        guard minutes > 0 else { return String(localized: "Not Set") }
        if minutes < 60 {
            return PlanoraLocalization.format(String(localized: "minutes_format"), minutes)
        }
        let hours = minutes / 60
        let remainder = minutes % 60
        if remainder == 0 {
            return PlanoraLocalization.format(String(localized: "hours_format"), hours)
        }
        return PlanoraLocalization.format(String(localized: "hours_minutes_format"), hours, remainder)
    }
}
