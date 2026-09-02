import Foundation
import SwiftData

@Model
final class PlanoraTopic {
    @Attribute(.unique) var id: UUID
    var subject: String
    var title: String
    var mastery: Double
    var notes: String
    var courseID: UUID?
    var createdDate: Date

    init(
        id: UUID = UUID(),
        subject: String,
        title: String,
        mastery: Double = 0,
        notes: String = "",
        courseID: UUID? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.subject = subject
        self.title = title
        self.mastery = min(max(mastery, 0), 1)
        self.notes = notes
        self.courseID = courseID
        self.createdDate = createdDate
    }
}
