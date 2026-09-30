import Foundation
import SwiftData

@MainActor
enum ImportRecovery {
    struct Snapshot: Codable {
        var content: String
        var teachers: [Teacher]
        var messages: [Message]
        var lessons: [Lesson]
        var subjects: [String]?
        var curriculum: Curriculum?
        var createdAt: Date
    }

    static var url: URL {
        let folder = Bundle.main.bundleIdentifier?.contains(".vlog") == true ? "Planora-Vlog" : "Planora"
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(folder).appendingPathComponent("LatestImport.json")
    }

    static func capture(_ context: ModelContext) throws -> Data {
        let profile = isLiveStore(context) ? PlanoraStorage.live.loadProfile() : nil
        let snapshot = Snapshot(
            content: try TaskBackupCodec.json(for: context.fetch(FetchDescriptor<PlanoraTask>()),
                courses: context.fetch(FetchDescriptor<PlanoraCourse>()),
                units: context.fetch(FetchDescriptor<PlanoraUnit>()),
                topics: context.fetch(FetchDescriptor<PlanoraTopic>()),
                assessments: context.fetch(FetchDescriptor<PlanoraAssessment>())),
            teachers: try context.fetch(FetchDescriptor<PlanoraTeacher>()).map(Teacher.init),
            messages: try context.fetch(FetchDescriptor<PlanoraMessage>()).map(Message.init),
            lessons: try context.fetch(FetchDescriptor<PlanoraScheduleEvent>()).map(Lesson.init),
            subjects: profile?.subjects, curriculum: profile?.curriculum, createdAt: Date())
        return try JSONEncoder().encode(snapshot)
    }

    // Persist before mutating the database. Failed imports restore the previous undo point.
    struct Ticket {
        let destination: URL
        let previous: Data?
    }

    private static func isPersistent(_ context: ModelContext) -> Bool {
        !context.container.configurations.allSatisfy(\.isStoredInMemoryOnly)
    }

    private static func isLiveStore(_ context: ModelContext) -> Bool {
        isPersistent(context) && context.container.configurations.contains {
            $0.url.deletingLastPathComponent().standardizedFileURL == url.deletingLastPathComponent().standardizedFileURL
        }
    }

    static func begin(_ context: ModelContext) throws -> Ticket? {
        guard isPersistent(context), let configuration = context.container.configurations.first else { return nil }
        let destination = configuration.url.deletingLastPathComponent().appendingPathComponent("LatestImport.json")
        let data = try capture(context)
        let previous = FileManager.default.fileExists(atPath: destination.path) ? try Data(contentsOf: destination) : nil
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: destination, options: .atomic)
        return Ticket(destination: destination, previous: previous)
    }

    static func failed(_ ticket: Ticket?) {
        guard let ticket else { return }
        do {
            if let previous = ticket.previous { try previous.write(to: ticket.destination, options: .atomic) }
            else { try FileManager.default.removeItem(at: ticket.destination) }
        } catch {
            NotificationCenter.default.post(name: PlanoraTaskPersistence.saveFailed, object: nil,
                userInfo: ["message": error.localizedDescription])
        }
    }

    static func restore(_ context: ModelContext, data: Data? = nil) throws -> Snapshot {
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: data ?? Data(contentsOf: url))
        let content = try TaskBackupCodec.content(from: snapshot.content, allowEmpty: true)
        do {
            try deleteRecords(context)
            content.tasks.forEach { context.insert($0) }
            content.courses.forEach { context.insert($0) }
            content.units.forEach { context.insert($0) }
            content.topics.forEach { context.insert($0) }
            content.assessments.forEach { context.insert($0) }
            snapshot.teachers.forEach { context.insert($0.model) }
            snapshot.messages.forEach { context.insert($0.model) }
            snapshot.lessons.forEach { context.insert($0.model) }
            try context.save()
        } catch { context.rollback(); throw error }
        if isLiveStore(context) {
            ManageBacConnectionStorage.clear()
            PlanoraTaskPersistence.reconcile(tasks: content.tasks)
            try? FileManager.default.removeItem(at: url)
        }
        return snapshot
    }

    static func clear(_ context: ModelContext) throws {
        do {
            try deleteRecords(context)
            try context.save()
        } catch { context.rollback(); throw error }
        if isLiveStore(context) {
            ManageBacConnectionStorage.clear()
            PlanoraTaskPersistence.reconcile(tasks: [])
            if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            try AutomaticTaskBackup.clear()
        }
    }

    private static func deleteRecords(_ context: ModelContext) throws {
        try context.fetch(FetchDescriptor<PlanoraTask>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraSubtask>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraResourceLink>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraAssessment>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraTopic>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraUnit>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraCourse>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraTeacher>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraMessage>()).forEach { context.delete($0) }
        try context.fetch(FetchDescriptor<PlanoraScheduleEvent>()).forEach { context.delete($0) }
    }

    struct Teacher: Codable {
        var id: UUID
        var externalIdentifier: String?
        var name: String
        var email: String?
        var courseIDs: [UUID]
        var unitIDs: [UUID]
        var lastSyncDate: Date?
        init(_ model: PlanoraTeacher) {
            id = model.id
            externalIdentifier = model.externalIdentifier
            name = model.name
            email = model.email
            courseIDs = model.courseIDs
            unitIDs = model.unitIDs
            lastSyncDate = model.lastSyncDate
        }
        var model: PlanoraTeacher {
            PlanoraTeacher(id: id, externalIdentifier: externalIdentifier, name: name, email: email, courseIDs: courseIDs, unitIDs: unitIDs, lastSyncDate: lastSyncDate)
        }
    }

    struct Message: Codable {
        var id: UUID
        var externalIdentifier: String
        var title: String
        var bodyPreview: String
        var senderName: String
        var publishedDate: Date?
        var isUnread: Bool
        var courseExternalIdentifier: String?
        var externalURLString: String?
        var lastSyncDate: Date
        init(_ model: PlanoraMessage) {
            id = model.id
            externalIdentifier = model.externalIdentifier
            title = model.title
            bodyPreview = model.bodyPreview
            senderName = model.senderName
            publishedDate = model.publishedDate
            isUnread = model.isUnread
            courseExternalIdentifier = model.courseExternalIdentifier
            externalURLString = model.externalURLString
            lastSyncDate = model.lastSyncDate
        }
        var model: PlanoraMessage {
            PlanoraMessage(id: id, externalIdentifier: externalIdentifier, title: title, bodyPreview: bodyPreview, senderName: senderName, publishedDate: publishedDate, isUnread: isUnread, courseExternalIdentifier: courseExternalIdentifier, externalURLString: externalURLString, lastSyncDate: lastSyncDate)
        }
    }

    struct Lesson: Codable {
        var id: UUID
        var externalIdentifier: String
        var title: String
        var courseExternalIdentifier: String?
        var startDate: Date
        var endDate: Date
        var location: String?
        var teacherNames: [String]
        var attendanceStatus: String?
        var externalURLString: String?
        var lastSyncDate: Date
        init(_ model: PlanoraScheduleEvent) {
            id = model.id
            externalIdentifier = model.externalIdentifier
            title = model.title
            courseExternalIdentifier = model.courseExternalIdentifier
            startDate = model.startDate
            endDate = model.endDate
            location = model.location
            teacherNames = model.teacherNames
            attendanceStatus = model.attendanceStatus
            externalURLString = model.externalURLString
            lastSyncDate = model.lastSyncDate
        }
        var model: PlanoraScheduleEvent {
            PlanoraScheduleEvent(id: id, externalIdentifier: externalIdentifier, title: title, courseExternalIdentifier: courseExternalIdentifier, startDate: startDate, endDate: endDate, location: location, teacherNames: teacherNames, attendanceStatus: attendanceStatus, externalURLString: externalURLString, lastSyncDate: lastSyncDate)
        }
    }
}
