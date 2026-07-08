import SwiftData
import SwiftUI

@main
struct PlanoraApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: PlanoraTask.self)
    }
}
