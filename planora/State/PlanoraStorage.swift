import Foundation

struct PlanoraStorage {
    var loadProfile: () -> LearningProfile?
    var saveProfile: (LearningProfile) -> Void
    var clearProfile: () -> Void

    static let live = PlanoraStorage(
        loadProfile: {
            guard let data = UserDefaults.standard.data(forKey: Keys.profile) else {
                return nil
            }
            return try? JSONDecoder().decode(LearningProfile.self, from: data)
        },
        saveProfile: { profile in
            guard let data = try? JSONEncoder().encode(profile) else {
                return
            }
            UserDefaults.standard.set(data, forKey: Keys.profile)
        },
        clearProfile: {
            UserDefaults.standard.removeObject(forKey: Keys.profile)
        }
    )

    static let preview = PlanoraStorage(
        loadProfile: { nil },
        saveProfile: { _ in },
        clearProfile: { }
    )

    private enum Keys {
        static let profile = "planora.learningProfile.v1"
    }
}
