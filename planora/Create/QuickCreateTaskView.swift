import SwiftData
import SwiftUI

struct QuickCreateTaskView: View {
    @Bindable var store: PlanoraStore
    let onComplete: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedSubject = ""
    @State private var hasDeadline = true
    @State private var deadline = Date()

    private var taskType: TaskType {
        let saved = QuickCreatePreferences.lastTaskType
        let available = TaskType.availableTypes(for: store.curriculum, selectedSubjects: store.selectedSubjectTitles)
        return available.contains(saved) ? saved : (available.first ?? .assignment)
    }

    private var subjectOptions: [String] {
        let options = store.selectedSubjectTitles + store.selectedExtraLearningTitles
        return Array(NSOrderedSet(array: options)) as? [String] ?? options
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedSubject.isEmpty
    }

    var body: some View {
        Form {
            Section {
                TextField(L("任务标题", "Task Title"), text: $title)
                    .planoraFont(.title3.weight(.semibold))
            }

            Section(L("科目", "Subject")) {
                Picker(L("科目", "Subject"), selection: $selectedSubject) {
                    ForEach(subjectOptions, id: \.self) { subject in
                        Text(PlanoraFormat.subjectDisplayName(subject)).tag(subject)
                    }
                }
            }

            Section(L("日期", "Date")) {
                Toggle(L("设置日期", "Set Date"), isOn: $hasDeadline)
                    .tint(taskType.tint)

                if hasDeadline {
                    DatePicker(L("日期", "Date"), selection: $deadline, displayedComponents: .date)
                }
            }

            Section {
                Label(
                    LF("quick_create_defaults_format", taskType.title, QuickCreatePreferences.reminderSummary),
                    systemImage: "bolt.fill"
                )
                .planoraFont(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(PlanoraBackground())
        .navigationTitle(L("快速新建", "Quick Create"))
        .planoraDetailNavigationBar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("保存", "Save"), action: save)
                    .fontWeight(.semibold)
                    .disabled(!canSave)
            }
        }
        .onAppear {
            if selectedSubject.isEmpty {
                let preferred = QuickCreatePreferences.lastSubject
                selectedSubject = subjectOptions.contains(preferred) ? preferred : (subjectOptions.first ?? "General")
                hasDeadline = QuickCreatePreferences.lastHasDeadline
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let task = PlanoraTask(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            subject: selectedSubject,
            type: taskType,
            deadline: hasDeadline ? deadline : nil,
            hasDeadline: hasDeadline,
            tracksProgress: taskType.tracksProgressByDefault,
            progressState: taskType.defaultProgressState,
            notes: "",
            importance: TaskPriority.medium.rawValue
        )
        task.reminders = hasDeadline
            ? QuickCreatePreferences.relativeReminders
            : []
        modelContext.insert(task)
        try? modelContext.save()
        QuickCreatePreferences.save(
            subject: selectedSubject,
            type: taskType,
            reminders: task.reminders,
            hasDeadline: hasDeadline
        )
        Task { await TaskReminderScheduler.synchronize(task: task) }
        store.selectedTab = .home
        onComplete?()
        dismiss()
    }
}

enum QuickCreatePreferences {
    private static let subjectKey = "planora.quickCreate.lastSubject"
    private static let typeKey = "planora.quickCreate.lastType"
    private static let deadlineKey = "planora.quickCreate.lastHasDeadline"
    private static let remindersKey = "planora.quickCreate.lastReminders"

    static var lastSubject: String {
        UserDefaults.standard.string(forKey: subjectKey) ?? ""
    }

    static var lastTaskType: TaskType {
        guard let rawValue = UserDefaults.standard.string(forKey: typeKey) else { return .assignment }
        return TaskType(rawValue: rawValue) ?? .assignment
    }

    static var lastHasDeadline: Bool {
        guard UserDefaults.standard.object(forKey: deadlineKey) != nil else { return true }
        return UserDefaults.standard.bool(forKey: deadlineKey)
    }

    static var relativeReminders: [TaskReminder] {
        guard let data = UserDefaults.standard.data(forKey: remindersKey),
              let reminders = try? JSONDecoder().decode([TaskReminder].self, from: data) else { return [] }
        return reminders.filter(\.isRelativeToDeadline)
    }

    @MainActor static var reminderSummary: String {
        relativeReminders.isEmpty
            ? L("无提醒", "No reminders")
            : LF("reminder_count_format", relativeReminders.count)
    }

    static func save(
        subject: String,
        type: TaskType,
        reminders: [TaskReminder],
        hasDeadline: Bool
    ) {
        let defaults = UserDefaults.standard
        defaults.set(subject, forKey: subjectKey)
        defaults.set(type.rawValue, forKey: typeKey)
        defaults.set(hasDeadline, forKey: deadlineKey)
        let reusable = reminders.filter(\.isRelativeToDeadline)
        defaults.set(try? JSONEncoder().encode(reusable), forKey: remindersKey)
    }
}
