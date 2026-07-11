import SwiftData
import SwiftUI

@main
struct PlanoraApp: App {
    @UIApplicationDelegateAdaptor(PlanoraAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: PlanoraTask.self)
    }
}
