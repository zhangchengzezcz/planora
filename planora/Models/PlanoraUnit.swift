import Foundation
import SwiftData

@Model
final class PlanoraUnit {
    @Attribute(.unique) var id: UUID
    var courseID: UUID
    var title: String
    var externalSourceRawValue: String?
    var externalIdentifier: String?
    var externalURLString: String?
    var startDate: Date?
    var endDate: Date?
    var officialProgress: Double?
    var isArchived: Bool
    var lastSyncDate: Date?

    init(
        id: UUID = UUID(),
        courseID: UUID,
        title: String,
        externalSource: ExternalTaskSource? = nil,
        externalIdentifier: String? = nil,
        externalURLString: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        officialProgress: Double? = nil,
        isArchived: Bool = false,
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.courseID = courseID
        self.title = title
        self.externalSourceRawValue = externalSource?.rawValue
        self.externalIdentifier = externalIdentifier
        self.externalURLString = externalURLString
        self.startDate = startDate
        self.endDate = endDate
        self.officialProgress = officialProgress.map { min(max($0, 0), 1) }
        self.isArchived = isArchived
        self.lastSyncDate = lastSyncDate
    }

    var externalSource: ExternalTaskSource? {
        get { externalSourceRawValue.flatMap(ExternalTaskSource.init(rawValue:)) }
        set { externalSourceRawValue = newValue?.rawValue }
    }

    func applyImportedValues(from source: PlanoraUnit) {
        courseID = source.courseID
        title = source.title
        externalSourceRawValue = source.externalSourceRawValue
        externalIdentifier = source.externalIdentifier
        externalURLString = source.externalURLString
        startDate = source.startDate
        endDate = source.endDate
        officialProgress = source.officialProgress
        isArchived = source.isArchived
        lastSyncDate = source.lastSyncDate
    }
}
