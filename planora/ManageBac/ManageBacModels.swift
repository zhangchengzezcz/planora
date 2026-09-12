import CryptoKit
import Foundation

extension Notification.Name {
    static let manageBacConnectionDidChange = Notification.Name("planora.managebac.connectionDidChange")
}

struct ManageBacConnectionSnapshot: Codable, Equatable {
    var schoolHost: String
    var lastSyncDate: Date
    var courseCount: Int
    var taskCount: Int
    var detectedCurriculumRawValue: String?
    var detectionConfidenceRawValue: String?
    var skippedItems: [String]? = nil

    var isConnected: Bool { !schoolHost.isEmpty }

    var detectedCurriculum: Curriculum? {
        detectedCurriculumRawValue.flatMap(Curriculum.init(rawValue:))
    }

    var detectionConfidence: ManageBacDetectionConfidence? {
        detectionConfidenceRawValue.flatMap(ManageBacDetectionConfidence.init(rawValue:))
    }
}

enum ManageBacConnectionStorage {
    private static let key = "planora.managebac.connection"

    static func load() -> ManageBacConnectionSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ManageBacConnectionSnapshot.self, from: data)
    }

    static func save(_ snapshot: ManageBacConnectionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
        NotificationCenter.default.post(name: .manageBacConnectionDidChange, object: nil)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
        NotificationCenter.default.post(name: .manageBacConnectionDidChange, object: nil)
    }
}

enum ManageBacAssessment {
    static func grade(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty,
              !["n/a", "na", "—", "-", "not assessed yet", "not assessed", "pending", "ungraded",
                "complete", "completed", "incomplete", "submitted", "not submitted", "missing", "overdue"].contains(value.lowercased()) else { return nil }
        return value
    }

    static func hasResult(grade value: String?, earned: Double?, possible: Double?) -> Bool {
        if grade(value) != nil { return true }
        guard let earned, let possible else { return false }
        return earned.isFinite && possible.isFinite && earned >= 0 && possible > 0
    }
}

struct ManageBacTaskRecord: Codable, Equatable, Sendable {
    var remoteIdentifier: String
    var title: String
    var subject: String
    var deadlineText: String?
    var detailURL: String?
    var sourceView: String
    var courseIdentifier: String?
    var unitIdentifier: String?
    var remoteStatus: ManageBacRemoteTaskStatus
    var remoteGradeText: String?
    var remoteScoreEarned: Double?
    var remoteScorePossible: Double?

    init(
        remoteIdentifier: String,
        title: String,
        subject: String,
        deadlineText: String?,
        detailURL: String?,
        sourceView: String,
        courseIdentifier: String? = nil,
        unitIdentifier: String? = nil,
        remoteStatus: ManageBacRemoteTaskStatus? = nil,
        remoteGradeText: String? = nil,
        remoteScoreEarned: Double? = nil,
        remoteScorePossible: Double? = nil
    ) {
        self.remoteIdentifier = remoteIdentifier
        self.title = title
        self.subject = subject
        self.deadlineText = deadlineText
        self.detailURL = detailURL
        self.sourceView = sourceView
        self.courseIdentifier = courseIdentifier
        self.unitIdentifier = unitIdentifier
        self.remoteStatus = remoteStatus ?? ManageBacRemoteTaskStatus(sourceView: sourceView)
        self.remoteGradeText = remoteGradeText
        self.remoteScoreEarned = remoteScoreEarned
        self.remoteScorePossible = remoteScorePossible
    }

    var stableIdentifier: String {
        if !remoteIdentifier.isEmpty { return remoteIdentifier }
        let seed = [sourceView, title, subject, deadlineText ?? ""].joined(separator: "|")
        return SHA256.hash(data: Data(seed.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    var deadline: Date? {
        guard let deadlineText, !deadlineText.isEmpty else { return nil }
        return ManageBacDateParser.date(from: deadlineText)
    }

    var inferredType: TaskType {
        let normalized = title.lowercased()
        let words = Set(normalized.split { !$0.isLetter && !$0.isNumber }.map(String.init))
        if normalized.contains("extended essay") || words.contains("ee") { return .ee }
        if normalized.contains("theory of knowledge") || words.contains("tok") { return .tok }
        if words.contains("cas") { return .cas }
        if normalized.contains("internal assessment") || words.contains("ia") { return .ia }
        if normalized.contains("exam") || normalized.contains("test") || normalized.contains("mock") { return .exam }
        if normalized.contains("revision") || normalized.contains("review") { return .revision }
        if normalized.contains("lab") || normalized.contains("practical") { return .practical }
        return .assignment
    }
}

enum ManageBacRemoteTaskStatus: String, Codable, Sendable {
    case upcoming
    case past
    case overdue
    case completed
    case unknown

    init(sourceView: String) {
        self = Self(rawValue: sourceView.lowercased()) ?? .unknown
    }
}

struct ManageBacCourseRecord: Codable, Equatable, Sendable, Identifiable {
    var remoteIdentifier: String
    var name: String
    var teacherNames: [String]
    var detailURL: String?
    var programmeText: String?

    var id: String { remoteIdentifier }
}

struct ManageBacUnitRecord: Codable, Equatable, Sendable, Identifiable {
    var remoteIdentifier: String
    var courseIdentifier: String
    var title: String
    var detailURL: String?
    var startDateText: String?
    var endDateText: String?
    var officialProgress: Double?
    var teacherNames: [String] = []

    var id: String { remoteIdentifier }
}

struct ManageBacMessageRecord: Codable, Equatable, Sendable, Identifiable {
    var remoteIdentifier: String
    var title: String
    var bodyPreview: String
    var senderName: String
    var publishedDateText: String?
    var isUnread: Bool
    var courseIdentifier: String?
    var detailURL: String?

    var id: String { remoteIdentifier }
}

struct ManageBacScheduleRecord: Codable, Equatable, Sendable, Identifiable {
    var remoteIdentifier: String
    var title: String
    var courseIdentifier: String?
    var startDateText: String
    var endDateText: String
    var location: String?
    var teacherNames: [String]
    var attendanceStatus: String?
    var detailURL: String?

    var id: String { remoteIdentifier }
}

struct ManageBacSyncSnapshot: Codable, Equatable, Sendable {
    var schoolHost: String
    var programmeText: String?
    var courses: [ManageBacCourseRecord]
    var units: [ManageBacUnitRecord]
    var tasks: [ManageBacTaskRecord]
    var messages: [ManageBacMessageRecord] = []
    var schedule: [ManageBacScheduleRecord] = []
}

enum ManageBacDetectionConfidence: String, Codable, Sendable {
    case high
    case medium
    case low
    case conflicting
}

struct ManageBacProgrammeDetection: Equatable, Sendable {
    var curriculum: Curriculum?
    var confidence: ManageBacDetectionConfidence
    var evidence: [String]
}

struct ManageBacScanPayload: Codable, Sendable {
    var records: [ManageBacTaskRecord]
    var pageRecognized: Bool
}

struct ManageBacImportSummary: Equatable, Sendable {
    var courseCount: Int
    var unitCount: Int = 0
    var importedCount: Int
    var updatedCount: Int
    var completedCount: Int = 0
    var reviewCount: Int = 0
    var teacherCount: Int = 0
    var messageCount: Int = 0
    var scheduleCount: Int = 0

    var totalTaskCount: Int { importedCount + updatedCount }
}

enum ManageBacDateParser {
    static func date(from value: String, calendar: Calendar = .current) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmed) { return date }
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: trimmed) { return date }

        for format in formats {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }

        return nil
    }

    private static let formats = [
        "yyyy-MM-dd'T'HH:mm:ssZ",
        "yyyy-MM-dd HH:mm:ss Z",
        "yyyy-MM-dd HH:mm",
        "yyyy-MM-dd",
        "MMM d, yyyy h:mm a",
        "MMM d, yyyy",
        "d MMM yyyy h:mm a",
        "d MMM yyyy"
    ]
}

enum ManageBacConnectionError: LocalizedError, Equatable {
    case unsupportedAddress
    case authenticationExpired
    case pageStructureChanged
    case invalidResponse
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unsupportedAddress:
            String(localized: "This page is not an official ManageBac page.")
        case .authenticationExpired:
            String(localized: "Your ManageBac session has expired. Please connect again.")
        case .pageStructureChanged:
            String(localized: "ManageBac changed this page, so syncing was paused without changing your tasks.")
        case .invalidResponse:
            String(localized: "Planora could not read the ManageBac response.")
        case .cancelled:
            String(localized: "Connection cancelled.")
        }
    }
}
