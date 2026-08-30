import Foundation
import SwiftData

@Model
final class PlanoraTeacher {
    @Attribute(.unique) var id: UUID
    var externalIdentifier: String?
    var name: String
    var email: String?
    var courseIDsData: Data?
    var unitIDsData: Data?
    var lastSyncDate: Date?

    init(
        id: UUID = UUID(),
        externalIdentifier: String? = nil,
        name: String,
        email: String? = nil,
        courseIDs: [UUID] = [],
        unitIDs: [UUID] = [],
        lastSyncDate: Date? = nil
    ) {
        self.id = id
        self.externalIdentifier = externalIdentifier
        self.name = name
        self.email = email
        self.courseIDsData = Self.encode(courseIDs)
        self.unitIDsData = Self.encode(unitIDs)
        self.lastSyncDate = lastSyncDate
    }

    var courseIDs: [UUID] {
        get { Self.decode(courseIDsData) }
        set { courseIDsData = Self.encode(newValue) }
    }

    var unitIDs: [UUID] {
        get { Self.decode(unitIDsData) }
        set { unitIDsData = Self.encode(newValue) }
    }

    private static func encode(_ values: [UUID]) -> Data? {
        let unique = Array(Set(values)).sorted { $0.uuidString < $1.uuidString }
        return unique.isEmpty ? nil : try? JSONEncoder().encode(unique)
    }

    private static func decode(_ data: Data?) -> [UUID] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([UUID].self, from: data)) ?? []
    }
}
