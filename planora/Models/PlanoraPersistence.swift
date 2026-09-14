import Foundation
import SQLite3
import SwiftData

@MainActor
enum PlanoraPersistence {
    static let models: [any PersistentModel.Type] = [
        PlanoraTask.self, PlanoraCourse.self, PlanoraUnit.self, PlanoraTeacher.self,
        PlanoraMessage.self, PlanoraScheduleEvent.self, PlanoraSubtask.self,
        PlanoraResourceLink.self, PlanoraTopic.self, PlanoraAssessment.self
    ]

    static func makeContainer() throws -> ModelContainer {
        let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                 appropriateFor: nil, create: true)
        let url = try prepareStore(in: support)
        return try ModelContainer(for: Schema(models), configurations: ModelConfiguration(url: url))
    }

    static func prepareStore(in support: URL) throws -> URL {
        let manager = FileManager.default
        let directory = support.appendingPathComponent("Planora", isDirectory: true)
        let destination = directory.appendingPathComponent("Planora.store")
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        guard !manager.fileExists(atPath: destination.path) else { return destination }
        let legacy = support.appendingPathComponent("default.store")
        guard manager.fileExists(atPath: legacy.path) else { return destination }

        var source: OpaquePointer?
        guard sqlite3_open_v2(legacy.path, &source, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            if let source { sqlite3_close(source) }
            throw CocoaError(.fileReadCorruptFile)
        }
        defer { sqlite3_close(source) }
        var statement: OpaquePointer?
        defer { sqlite3_finalize(statement) }
        guard sqlite3_prepare_v2(source, "SELECT name FROM sqlite_master WHERE type='table' AND name='ZPLANORATASK'", -1, &statement, nil) == SQLITE_OK,
              sqlite3_step(statement) == SQLITE_ROW else {
            // The generic filename may belong to another app. Never adopt an unrelated store.
            throw CocoaError(.fileReadUnknown)
        }
        sqlite3_finalize(statement)
        statement = nil

        let staging = directory.appendingPathComponent("migration-\(UUID().uuidString).store")
        defer { try? manager.removeItem(at: staging) }
        var target: OpaquePointer?
        guard sqlite3_open(staging.path, &target) == SQLITE_OK else {
            if let target { sqlite3_close(target) }
            throw CocoaError(.fileWriteUnknown)
        }
        // SQLite's backup API includes committed WAL pages in one consistent snapshot.
        guard let backup = sqlite3_backup_init(target, "main", source, "main") else {
            sqlite3_close(target)
            throw CocoaError(.fileReadCorruptFile)
        }
        let result = sqlite3_backup_step(backup, -1)
        let finish = sqlite3_backup_finish(backup)
        sqlite3_close(target)
        guard result == SQLITE_DONE, finish == SQLITE_OK else { throw CocoaError(.fileReadCorruptFile) }
        try manager.moveItem(at: staging, to: destination)
        return destination
    }
}
