import SwiftUI
import SwiftData
import UserNotifications

struct TaskReminderEditorView: View {
    @Bindable var task: PlanoraTask

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var reminders: [TaskReminder]

    init(task: PlanoraTask) {
        self.task = task
        _reminders = State(initialValue: task.reminders)
    }

    var body: some View {
        ReminderConfigurationView(
            reminders: $reminders,
            deadline: task.hasDeadline ? task.deadline : nil,
            tint: task.type.tint
        )
        .navigationTitle(L("提醒", "Reminders"))
        .planoraDetailNavigationBar()
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L("保存", "Save"), action: save)
                    .fontWeight(.semibold)
            }
        }
    }

    private func save() {
        let validReminders = task.hasDeadline
            ? reminders
            : reminders.filter { !$0.isRelativeToDeadline }
        task.replaceReminders(with: validReminders)
        PlanoraTaskPersistence.saveAndSynchronize(task, in: modelContext)
        dismiss()
    }
}

struct ReminderDraftEditorView: View {
    @Binding var reminders: [TaskReminder]
    let deadline: Date?
    let tint: Color

    var body: some View {
        ReminderConfigurationView(
            reminders: $reminders,
            deadline: deadline,
            tint: tint
        )
        .navigationTitle(L("提醒", "Reminders"))
        .planoraDetailNavigationBar()
    }
}

private struct ReminderConfigurationView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var reminders: [TaskReminder]
    let deadline: Date?
    let tint: Color

    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @State private var relativeTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    private let presets: [TaskReminderTiming] = [
        .daysBefore(7),
        .daysBefore(3),
        .daysBefore(1),
        .atDeadline,
        .daysAfter(1)
    ]

    private var notificationsAllowed: Bool {
        authorizationStatus == .authorized
            || authorizationStatus == .provisional
            || authorizationStatus == .ephemeral
    }

    private var hasRelativeReminder: Bool {
        reminders.contains(where: \.isRelativeToDeadline)
    }

    var body: some View {
        Form {
            permissionSection

            if notificationsAllowed {
                if deadline != nil {
                    deadlineReminderSection
                } else {
                    Section {
                        Label(
                            L("没有 Deadline 的任务只能使用自定义提醒。", "Tasks without a deadline can only use custom reminders."),
                            systemImage: "info.circle"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }

                customReminderSection
            }
        }
        .scrollContentBackground(.hidden)
        .background(PlanoraBackground())
        .task {
            await refreshAuthorizationStatus()
            loadRelativeTime()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await refreshAuthorizationStatus() }
        }
    }

    private var permissionSection: some View {
        Section(L("通知权限", "Notification Access")) {
            switch authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                Label(L("通知已启用", "Notifications Enabled"), systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color.planoraGreen)
            case .denied:
                VStack(alignment: .leading, spacing: 10) {
                    Label(L("通知权限已关闭", "Notifications Are Off"), systemImage: "bell.slash.fill")
                        .font(.headline)
                        .foregroundStyle(.red)

                    Text(L("请在系统设置中允许 Planora 发送通知。", "Allow Planora notifications in System Settings to use reminders."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(L("打开系统设置", "Open Settings"), action: openSettings)
                        .fontWeight(.semibold)
                }
                .padding(.vertical, 4)
            case .notDetermined:
                VStack(alignment: .leading, spacing: 10) {
                    Text(L("启用通知后，Planora 会在你选择的时间提醒任务。", "Enable notifications so Planora can remind you at the times you choose."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { authorizationStatus = await TaskReminderScheduler.requestAuthorization() }
                    } label: {
                        Label(L("启用通知", "Enable Notifications"), systemImage: "bell.badge.fill")
                            .fontWeight(.semibold)
                            .foregroundStyle(tint)
                    }
                }
                .padding(.vertical, 4)
            @unknown default:
                Text(L("无法读取通知权限状态。", "Notification access status is unavailable."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var deadlineReminderSection: some View {
        Section {
            ForEach(presets, id: \.self) { timing in
                Toggle(timing.title, isOn: selectionBinding(for: timing))
                    .tint(tint)
            }

            if hasRelativeReminder {
                DatePicker(
                    L("提醒时间", "Reminder Time"),
                    selection: $relativeTime,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: relativeTime) { _, newValue in
                    applyRelativeTime(newValue)
                }
            }
        } header: {
            Text(L("Deadline 提醒", "Deadline Reminders"))
        } footer: {
            Text(L("逾期提醒只会在任务仍未完成时保留。", "Overdue reminders are removed automatically when the task is completed."))
        }
    }

    private var customReminderSection: some View {
        Section {
            ForEach($reminders) { $reminder in
                if case .custom = reminder.timing {
                    CustomReminderRow(reminder: $reminder) {
                        reminders.removeAll { $0.id == reminder.id }
                    }
                }
            }

            Button(action: addCustomReminder) {
                Label(L("添加自定义提醒", "Add Custom Reminder"), systemImage: "plus.circle.fill")
                    .foregroundStyle(tint)
            }
        } header: {
            Text(L("自定义提醒", "Custom Reminders"))
        } footer: {
            Text(L("可以添加多个自定义日期和时间。", "You can add multiple custom dates and times."))
        }
    }

    private func selectionBinding(for timing: TaskReminderTiming) -> Binding<Bool> {
        Binding(
            get: { reminders.contains { $0.timing == timing } },
            set: { isSelected in
                if isSelected {
                    guard !reminders.contains(where: { $0.timing == timing }) else { return }
                    let components = Calendar.current.dateComponents([.hour, .minute], from: relativeTime)
                    reminders.append(
                        TaskReminder(
                            timing: timing,
                            hour: components.hour ?? 9,
                            minute: components.minute ?? 0
                        )
                    )
                } else {
                    reminders.removeAll { $0.timing == timing }
                }
            }
        )
    }

    private func addCustomReminder() {
        let nextHour = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        reminders.append(TaskReminder(timing: .custom(nextHour)))
    }

    private func loadRelativeTime() {
        guard let reminder = reminders.first(where: \.isRelativeToDeadline) else { return }
        relativeTime = Calendar.current.date(
            bySettingHour: reminder.hour,
            minute: reminder.minute,
            second: 0,
            of: Date()
        ) ?? relativeTime
    }

    private func applyRelativeTime(_ date: Date) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        for index in reminders.indices where reminders[index].isRelativeToDeadline {
            reminders[index].hour = components.hour ?? 9
            reminders[index].minute = components.minute ?? 0
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await TaskReminderScheduler.authorizationStatus()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

private struct CustomReminderRow: View {
    @Binding var reminder: TaskReminder
    let onDelete: () -> Void

    private var date: Binding<Date> {
        Binding(
            get: {
                guard case .custom(let date) = reminder.timing else { return Date() }
                return date
            },
            set: { reminder.timing = .custom($0) }
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            DatePicker(
                L("自定义时间", "Custom Time"),
                selection: date,
                displayedComponents: [.date, .hourAndMinute]
            )

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L("删除提醒", "Delete Reminder"))
        }
    }
}
