import Foundation
import SwiftData

@Model
final class PlanoraCourse {
    @Attribute(.unique) var id: UUID
    var displayName: String
    var originalName: String
    var canonicalSubject: String
    var levelRawValue: String?
    var curriculumRawValue: String
    var teacherNamesData: Data?
    var externalSourceRawValue: String?
    var externalIdentifier: String?
    var externalURLString: String?
    var isArchived: Bool
    var needsRemoteReview: Bool
    var lastSyncDate: Date?

    init(
        id: UUID = UUID(),
        displayName: String,
        originalName: String? = nil,
        canonicalSubject: String? = nil,
        level: CourseLevel? = nil,
        curriculum: Curriculum,
        teacherNames: [String] = [],
        externalSource: ExternalTaskSource? = nil,
        externalIdentifier: String? = nil,
        externalURLString: String? = nil,
        isArchived: Bool = false,
        needsRemoteReview: Bool = false,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.originalName = originalName ?? displayName
        self.canonicalSubject = canonicalSubject ?? displayName
        self.levelRawValue = level?.rawValue
        self.curriculumRawValue = curriculum.rawValue
        self.teacherNamesData = Self.encodeNames(teacherNames)
        self.externalSourceRawValue = externalSource?.rawValue
        self.externalIdentifier = externalIdentifier
        self.externalURLString = externalURLString
        self.isArchived = isArchived
        self.needsRemoteReview = needsRemoteReview
        self.lastSyncDate = lastSyncDate
    }

    var curriculum: Curriculum {
        get { Curriculum(rawValue: curriculumRawValue) ?? .ib }
        set { curriculumRawValue = newValue.rawValue }
    }

    var level: CourseLevel? {
        get { levelRawValue.flatMap(CourseLevel.init(rawValue:)) }
        set { levelRawValue = newValue?.rawValue }
    }

    var teacherNames: [String] {
        get {
            guard let teacherNamesData,
                  let values = try? JSONDecoder().decode([String].self, from: teacherNamesData) else { return [] }
            return values
        }
        set { teacherNamesData = Self.encodeNames(newValue) }
    }

    var externalSource: ExternalTaskSource? {
        get { externalSourceRawValue.flatMap(ExternalTaskSource.init(rawValue:)) }
        set { externalSourceRawValue = newValue?.rawValue }
    }

    private static func encodeNames(_ names: [String]) -> Data? {
        let normalized = Array(Set(names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
        return normalized.isEmpty ? nil : try? JSONEncoder().encode(normalized)
    }

    func applyImportedValues(from source: PlanoraCourse) {
        displayName = source.displayName
        originalName = source.originalName
        canonicalSubject = source.canonicalSubject
        levelRawValue = source.levelRawValue
        curriculumRawValue = source.curriculumRawValue
        teacherNames = source.teacherNames
        externalSourceRawValue = source.externalSourceRawValue
        externalIdentifier = source.externalIdentifier
        externalURLString = source.externalURLString
        isArchived = source.isArchived
        needsRemoteReview = source.needsRemoteReview
        lastSyncDate = source.lastSyncDate
    }
}

enum CourseLevel: String, Codable, CaseIterable, Sendable {
    case hl
    case sl

    var title: String { rawValue.uppercased() }
}
