import Foundation
import SwiftData
import SwiftUI

struct QuickCreateTaskView: View {
    @Bindable var store: PlanoraStore
    let onComplete: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PlanoraCourse.displayName) private var courses: [PlanoraCourse]
    @State private var title = ""
    @State private var selectedSubject = ""
    @State private var hasDeadline = true
    @State private var deadline = Date()
    @State private var recognizedTaskType: TaskType?
    @State private var priority: TaskPriority = .medium

    private var taskType: TaskType {
        if let recognizedTaskType, availableTaskTypes.contains(recognizedTaskType) {
            return recognizedTaskType
        }
        let saved = QuickCreatePreferences.lastTaskType
        return availableTaskTypes.contains(saved) ? saved : (availableTaskTypes.first ?? .assignment)
    }

    private var availableTaskTypes: [TaskType] {
        TaskType.availableTypes(for: store.curriculum, selectedSubjects: store.selectedSubjectTitles)
    }

    private var subjectOptions: [String] {
        let options = store.selectedSubjectTitles + store.selectedExtraLearningTitles
        return Array(NSOrderedSet(array: options)) as? [String] ?? options
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !selectedSubject.isEmpty
    }

    private var recognition: TaskRecognitionResult {
        TaskTextRecognizer.recognize(
            title,
            subjects: subjectOptions,
            availableTypes: availableTaskTypes
        )
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Task Title"), text: $title)
                    .font(.title3.weight(.semibold))

                if recognition.hasRecognizedMetadata {
                    RecognitionPreview(result: recognition, action: applyRecognition)
                }
            }

            Section(String(localized: "Subject")) {
                Picker(String(localized: "Subject"), selection: $selectedSubject) {
                    ForEach(subjectOptions, id: \.self) { subject in
                        Text(PlanoraFormat.subjectDisplayName(subject)).tag(subject)
                    }
                }
            }

            Section(String(localized: "Date")) {
                Toggle(String(localized: "Set Date"), isOn: $hasDeadline)
                    .tint(taskType.tint)

                if hasDeadline {
                    DatePicker(String(localized: "Date"), selection: $deadline, displayedComponents: .date)
                }
            }

            Section {
                Label(
                    PlanoraLocalization.format(String(localized: "quick_create_defaults_format"), taskType.title, QuickCreatePreferences.reminderSummary),
                    systemImage: "bolt.fill"
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                if priority != .medium {
                    Label(priority.title, systemImage: priority.symbol)
                        .font(.caption)
                        .foregroundStyle(priority == .high ? .red : .secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PlanoraBackground())
        .navigationTitle(String(localized: "Quick Create"))
        .planoraDetailNavigationBar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "Save"), action: save)
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
            importance: priority.rawValue
        )
        task.courseID = courses.first {
            !$0.isArchived && ($0.displayName == selectedSubject || $0.originalName == selectedSubject)
        }?.id
        task.reminders = hasDeadline
            ? QuickCreatePreferences.relativeReminders
            : []
        modelContext.insert(task)
        PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
        QuickCreatePreferences.save(
            subject: selectedSubject,
            type: taskType,
            reminders: task.reminders,
            hasDeadline: hasDeadline
        )
        store.selectedTab = .home
        onComplete?()
        dismiss()
    }

    private func applyRecognition() {
        let result = recognition
        guard result.hasRecognizedMetadata else { return }

        title = result.title
        if let subject = result.subject, subjectOptions.contains(subject) {
            selectedSubject = subject
        }
        if let type = result.type, availableTaskTypes.contains(type) {
            recognizedTaskType = type
        }
        if let deadline = result.deadline {
            self.deadline = deadline
            hasDeadline = true
        }
        if let priority = result.priority {
            self.priority = priority
        }
    }
}

private struct RecognitionPreview: View {
    let result: TaskRecognitionResult
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let subject = result.subject {
                        RecognitionChip(title: PlanoraFormat.subjectDisplayName(subject), systemImage: "book.closed.fill")
                    }
                    if let type = result.type {
                        RecognitionChip(title: type.title, systemImage: type.symbol)
                    }
                    if let deadline = result.deadline {
                        RecognitionChip(title: PlanoraFormat.monthDay(deadline), systemImage: "calendar")
                    }
                    if let priority = result.priority {
                        RecognitionChip(title: priority.title, systemImage: priority.symbol)
                    }
                }
            }

            Button(String(localized: "Apply"), action: action)
                .font(.subheadline.weight(.semibold))
        }
    }
}

private struct RecognitionChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.planoraInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.planoraGlassFill, in: Capsule())
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
            ? String(localized: "No reminders")
            : PlanoraLocalization.format(String(localized: "reminder_count_format"), relativeReminders.count)
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
