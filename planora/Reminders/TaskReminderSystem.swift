import Foundation
import UIKit
import UserNotifications

struct TaskReminder: Codable, Identifiable, Hashable {
    var id = UUID()
    var timing: TaskReminderTiming
    var hour: Int = 9
    var minute: Int = 0

    var isRelativeToDeadline: Bool {
        switch timing {
        case .custom:
            false
        case .daysBefore, .atDeadline, .daysAfter:
            true
        }
    }

    func fireDate(deadline: Date?, calendar: Calendar = .current) -> Date? {
        switch timing {
        case .custom(let date):
            return date
        case .daysBefore(let days):
            guard let deadline else { return nil }
            return relativeDate(from: deadline, dayOffset: -days, calendar: calendar)
        case .atDeadline:
            guard let deadline else { return nil }
            return relativeDate(from: deadline, dayOffset: 0, calendar: calendar)
        case .daysAfter(let days):
            guard let deadline else { return nil }
            return relativeDate(from: deadline, dayOffset: days, calendar: calendar)
        }
    }

    private func relativeDate(from deadline: Date, dayOffset: Int, calendar: Calendar) -> Date? {
        guard let shiftedDate = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: deadline)) else {
            return nil
        }

        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: shiftedDate)
    }

    var configurationKey: String {
        switch timing {
        case .daysBefore(let days):
            "before:\(days):\(hour):\(minute)"
        case .atDeadline:
            "deadline:\(hour):\(minute)"
        case .daysAfter(let days):
            "after:\(days):\(hour):\(minute)"
        case .custom(let date):
            "custom:\(Int(date.timeIntervalSince1970 / 60))"
        }
    }

    static func deduplicated(_ reminders: [TaskReminder]) -> [TaskReminder] {
        var seen: Set<String> = []
        return reminders.filter { seen.insert($0.configurationKey).inserted }
    }
}

struct TaskReminderCandidate {
    let task: PlanoraTask
    let reminder: TaskReminder
    let fireDate: Date
}

enum TaskReminderTiming: Codable, Hashable {
    case daysBefore(Int)
    case atDeadline
    case custom(Date)
    case daysAfter(Int)

    var title: String {
        switch self {
        case .daysBefore(let days):
            PlanoraLocalization.format(String(localized: "days_before_deadline_format"), days)
        case .atDeadline:
            String(localized: "On Due Date")
        case .custom:
            String(localized: "Custom Time")
        case .daysAfter(let days):
            PlanoraLocalization.format(String(localized: "days_after_deadline_format"), days)
        }
    }
}

@MainActor
enum TaskReminderScheduler {
    static let categoryIdentifier = "PLANORA_TASK_REMINDER"
    static let snoozeHourAction = "PLANORA_SNOOZE_ONE_HOUR"
    static let snoozeTomorrowAction = "PLANORA_SNOOZE_TOMORROW"
    private static let identifierPrefix = "planora.task."

    static func configureCategories() {
        let hourAction = UNNotificationAction(
            identifier: snoozeHourAction,
            title: String(localized: "Remind in 1 Hour"),
            options: []
        )
        let tomorrowAction = UNNotificationAction(
            identifier: snoozeTomorrowAction,
            title: String(localized: "Remind Tomorrow"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [hourAction, tomorrowAction],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> UNAuthorizationStatus {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            return await authorizationStatus()
        }
        return await authorizationStatus()
    }

    static func synchronize(task: PlanoraTask) async {
        await removeRequests(forTaskID: task.id)
        guard !task.isCompleted else { return }

        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        for reminder in task.reminders {
            guard let fireDate = reminder.fireDate(deadline: task.deadline), fireDate > Date() else { continue }
            await schedule(reminder: reminder, for: task, fireDate: fireDate)
        }
    }

    static func reconcile(tasks: [PlanoraTask], requestLimit: Int = 48) async {
        let center = UNUserNotificationCenter.current()
        let status = await authorizationStatus()
        let notificationsAllowed = status == .authorized || status == .provisional || status == .ephemeral
        let activeTaskIDs = Set(tasks.filter { !$0.isCompleted }.map(\.id))
        let taskRequestIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { identifier in
                guard identifier.hasPrefix(identifierPrefix) else { return false }
                if notificationsAllowed,
                   isSnoozeRequest(identifier),
                   let taskID = taskID(fromRequestIdentifier: identifier),
                   activeTaskIDs.contains(taskID) {
                    return false
                }
                return true
            }
        center.removePendingNotificationRequests(withIdentifiers: taskRequestIDs)

        // Clear stale requests when access was revoked. If access is granted again,
        // the next reconciliation builds a fresh queue while valid snoozes survive
        // ordinary foreground refreshes.
        guard status == .authorized || status == .provisional || status == .ephemeral else { return }

        let candidates = candidates(tasks: tasks, limit: requestLimit)

        for candidate in candidates {
            await schedule(reminder: candidate.reminder, for: candidate.task, fireDate: candidate.fireDate)
        }
    }

    static func candidates(tasks: [PlanoraTask], now: Date = Date(), limit: Int = 48) -> [TaskReminderCandidate] {
        var seenFireTimes: Set<String> = []
        return tasks
            .filter { !$0.isCompleted }
            .flatMap { task in
                task.reminders.compactMap { reminder -> TaskReminderCandidate? in
                    guard let date = reminder.fireDate(deadline: task.deadline), date > now else { return nil }
                    return TaskReminderCandidate(task: task, reminder: reminder, fireDate: date)
                }
            }
            .sorted { $0.fireDate < $1.fireDate }
            .filter { candidate in
                let key = "\(candidate.task.id.uuidString):\(Int(candidate.fireDate.timeIntervalSince1970 / 60))"
                return seenFireTimes.insert(key).inserted
            }
            .prefix(max(limit, 0))
            .map { $0 }
    }

    static func removeRequests(forTaskID taskID: UUID) async {
        let prefix = taskIdentifierPrefix(taskID)
        let center = UNUserNotificationCenter.current()
        let pendingIDs = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        let deliveredIDs = await center.deliveredNotifications()
            .map { $0.request.identifier }
            .filter { $0.hasPrefix(prefix) }

        center.removePendingNotificationRequests(withIdentifiers: pendingIDs)
        center.removeDeliveredNotifications(withIdentifiers: deliveredIDs)
    }

    static func removeRequests(for tasks: [PlanoraTask]) async {
        for task in tasks {
            await removeRequests(forTaskID: task.id)
        }
    }

    static func removeRequests(forTaskIDs taskIDs: [UUID]) async {
        for taskID in taskIDs {
            await removeRequests(forTaskID: taskID)
        }
    }

    static func snooze(content: UNNotificationContent, after interval: TimeInterval) async {
        let mutableContent = content.mutableCopy() as? UNMutableNotificationContent
            ?? UNMutableNotificationContent()
        mutableContent.sound = .default
        mutableContent.categoryIdentifier = categoryIdentifier

        let request = UNNotificationRequest(
            identifier: snoozeRequestIdentifier(content: content),
            content: mutableContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(interval, 60), repeats: false)
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    static func snoozeRequestIdentifier(content: UNNotificationContent) -> String {
        if let taskIDString = content.userInfo["taskID"] as? String,
           let taskID = UUID(uuidString: taskIDString) {
            return "\(taskIdentifierPrefix(taskID))snooze.\(UUID().uuidString)"
        }
        return "planora.snooze.\(UUID().uuidString)"
    }

    static func isSnoozeRequest(_ identifier: String) -> Bool {
        identifier.hasPrefix(identifierPrefix) && identifier.contains(".snooze.")
    }

    static func taskID(fromRequestIdentifier identifier: String) -> UUID? {
        guard identifier.hasPrefix(identifierPrefix) else { return nil }
        let remainder = identifier.dropFirst(identifierPrefix.count)
        guard let separator = remainder.firstIndex(of: ".") else { return nil }
        return UUID(uuidString: String(remainder[..<separator]))
    }

    private static func requestIdentifier(taskID: UUID, reminderID: UUID) -> String {
        "\(taskIdentifierPrefix(taskID))\(reminderID.uuidString)"
    }

    private static func schedule(reminder: TaskReminder, for task: PlanoraTask, fireDate: Date) async {
        let content = UNMutableNotificationContent()
        content.title = task.title
        content.body = notificationBody(for: task)
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "taskID": task.id.uuidString,
            "reminderID": reminder.id.uuidString
        ]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: requestIdentifier(taskID: task.id, reminderID: reminder.id),
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func taskIdentifierPrefix(_ taskID: UUID) -> String {
        "\(identifierPrefix)\(taskID.uuidString)."
    }

    private static func notificationBody(for task: PlanoraTask) -> String {
        guard task.hasDeadline, let deadline = task.deadline else {
            return PlanoraLocalization.format(String(localized: "task_reminder_no_deadline_format"), PlanoraFormat.subjectDisplayName(task.subject))
        }
        return PlanoraLocalization.format(
            String(localized: "task_reminder_deadline_format"),
            PlanoraFormat.subjectDisplayName(task.subject),
            PlanoraFormat.monthDay(deadline)
        )
    }
}

final class PlanoraAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        TaskReminderScheduler.configureCategories()
        return true
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let interval: TimeInterval?
        switch response.actionIdentifier {
        case TaskReminderScheduler.snoozeHourAction:
            interval = 60 * 60
        case TaskReminderScheduler.snoozeTomorrowAction:
            interval = 24 * 60 * 60
        default:
            interval = nil
        }

        guard let interval else {
            completionHandler()
            return
        }

        Task {
            await TaskReminderScheduler.snooze(content: response.notification.request.content, after: interval)
            completionHandler()
        }
    }
}
