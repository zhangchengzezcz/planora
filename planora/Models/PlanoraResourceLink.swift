import Foundation
import SwiftData

@Model
final class PlanoraResourceLink {
    @Attribute(.unique) var id: UUID
    var title: String
    var urlString: String
    var createdDate: Date
    var task: PlanoraTask?

    init(
        id: UUID = UUID(),
        title: String,
        urlString: String,
        createdDate: Date = Date(),
        task: PlanoraTask? = nil
    ) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdDate = createdDate
        self.task = task
    }

    var url: URL? { URL(string: urlString) }
}
