import Foundation
import SwiftData

@Model
final class PlanoraScheduleEvent {
    @Attribute(.unique) var id: UUID
    var externalIdentifier: String
    var title: String
    var courseExternalIdentifier: String?
    var startDate: Date
    var endDate: Date
    var location: String?
    var teacherNamesData: Data?
    var attendanceStatus: String?
    var externalURLString: String?
    var lastSyncDate: Date

    init(
        id: UUID = UUID(),
        externalIdentifier: String,
        title: String,
        courseExternalIdentifier: String? = nil,
        startDate: Date,
        endDate: Date,
        location: String? = nil,
        teacherNames: [String] = [],
        attendanceStatus: String? = nil,
        externalURLString: String? = nil,
        lastSyncDate: Date = Date()
    ) {
        self.id = id
        self.externalIdentifier = externalIdentifier
        self.title = title
        self.courseExternalIdentifier = courseExternalIdentifier
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.teacherNamesData = teacherNames.isEmpty ? nil : try? JSONEncoder().encode(teacherNames)
        self.attendanceStatus = attendanceStatus
        self.externalURLString = externalURLString
        self.lastSyncDate = lastSyncDate
    }

    var teacherNames: [String] {
        get {
            guard let teacherNamesData else { return [] }
            return (try? JSONDecoder().decode([String].self, from: teacherNamesData)) ?? []
        }
        set { teacherNamesData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }
}
