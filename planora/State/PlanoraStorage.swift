import Foundation

struct PlanoraStorage {
    var loadProfile: () -> LearningProfile?
    var saveProfile: (LearningProfile) -> Void
    var clearProfile: () -> Void

    static let live = persistent(profileURL: profileURL, defaults: .standard)

    static func persistent(profileURL: URL?, defaults: UserDefaults) -> PlanoraStorage {
        PlanoraStorage(
        loadProfile: {
            if let data = defaults.data(forKey: Keys.profile),
               let profile = try? JSONDecoder().decode(LearningProfile.self, from: data) {
                if (try? persist(data, to: profileURL)) != nil {
                    defaults.removeObject(forKey: Keys.profile)
                }
                return profile
            }
            guard let url = profileURL, let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(LearningProfile.self, from: data)
        },
        saveProfile: { profile in
            guard let data = try? JSONEncoder().encode(profile) else {
                return
            }
            do {
                try persist(data, to: profileURL)
                defaults.removeObject(forKey: Keys.profile)
            } catch {
                // Retain a recoverable profile if disk persistence is unavailable.
                defaults.set(data, forKey: Keys.profile)
                NotificationCenter.default.post(name: Notification.Name("PlanoraTaskPersistence.saveFailed"),
                    object: nil, userInfo: ["message": error.localizedDescription])
            }
        },
        clearProfile: {
            if let url = profileURL { try? FileManager.default.removeItem(at: url) }
            defaults.removeObject(forKey: Keys.profile)
        }
    )

    }

    private static var profileURL: URL? {
        let folder = Bundle.main.bundleIdentifier?.contains(".vlog") == true ? "Planora-Vlog" : "Planora"
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("LearningProfile.json")
    }

    private static func persist(_ data: Data, to profileURL: URL?) throws {
        guard let url = profileURL else { throw CocoaError(.fileWriteUnknown) }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    static let preview = PlanoraStorage(
        loadProfile: { nil },
        saveProfile: { _ in },
        clearProfile: { }
    )

    private enum Keys {
        static let profile = "planora.learningProfile.v1"
    }
}
