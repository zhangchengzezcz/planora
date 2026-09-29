import XCTest
@testable import planora

final class ProfilePersistenceTests: XCTestCase {
    func testLegacyProfileSurvivesPreferenceRemoval() throws {
        let name = "ProfilePersistenceTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        defer {
            defaults.removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: directory)
        }
        let profile = LearningProfile(name: "Student", curriculum: .igcse,
            subjects: ["Mathematics"], extraLearning: [], completedTasks: 0, totalTasks: 0)
        defaults.set(try JSONEncoder().encode(profile), forKey: "planora.learningProfile.v1")
        let url = directory.appendingPathComponent("LearningProfile.json")
        let storage = PlanoraStorage.persistent(profileURL: url, defaults: defaults)
        XCTAssertEqual(storage.loadProfile(), profile)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        defaults.removePersistentDomain(forName: name)
        XCTAssertEqual(storage.loadProfile(), profile)
        var edited = profile
        edited.name = "Updated"
        storage.saveProfile(edited)
        XCTAssertEqual(storage.loadProfile(), edited)
        storage.clearProfile()
        XCTAssertNil(storage.loadProfile())
    }
}
