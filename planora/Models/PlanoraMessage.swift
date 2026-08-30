import Foundation
import SwiftData

@Model
final class PlanoraMessage {
    @Attribute(.unique) var id: UUID
    var externalIdentifier: String
    var title: String
    var bodyPreview: String
    var senderName: String
    var publishedDate: Date?
    var isUnread: Bool
    var courseExternalIdentifier: String?
    var externalURLString: String?
    var lastSyncDate: Date

    init(
        id: UUID = UUID(),
        externalIdentifier: String,
        title: String,
        bodyPreview: String = "",
        senderName: String = "",
        publishedDate: Date? = nil,
        isUnread: Bool = false,
        courseExternalIdentifier: String? = nil,
        externalURLString: String? = nil,
        lastSyncDate: Date = Date()
    ) {
        self.id = id
        self.externalIdentifier = externalIdentifier
        self.title = title
        self.bodyPreview = bodyPreview
        self.senderName = senderName
        self.publishedDate = publishedDate
        self.isUnread = isUnread
        self.courseExternalIdentifier = courseExternalIdentifier
        self.externalURLString = externalURLString
        self.lastSyncDate = lastSyncDate
    }
}
