import Foundation
import SwiftData

@Model
final class PlanoraSubtask {
    @Attribute(.unique) var id: UUID
    var title: String
    var isCompleted: Bool
    var sortOrder: Int
    var targetDate: Date?
    var estimatedMinutes: Int
    var createdDate: Date
    var task: PlanoraTask?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        sortOrder: Int = 0,
        targetDate: Date? = nil,
        estimatedMinutes: Int = 0,
        createdDate: Date = Date(),
        task: PlanoraTask? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.sortOrder = sortOrder
        self.targetDate = targetDate
        self.estimatedMinutes = max(estimatedMinutes, 0)
        self.createdDate = createdDate
        self.task = task
    }
}
