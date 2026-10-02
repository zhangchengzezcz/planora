import SwiftData
import SwiftUI

@main
struct PlanoraApp: App {
#if os(iOS)
    @UIApplicationDelegateAdaptor(PlanoraAppDelegate.self) private var appDelegate
#else
    @NSApplicationDelegateAdaptor(PlanoraAppDelegate.self) private var appDelegate
#endif
    @State private var store = PlanoraStore()
    private let persistence = Result { try PlanoraPersistence.makeContainer() }

    @ViewBuilder
    private func storedContent<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        switch persistence {
        case .success(let container):
            #if os(macOS)
            content().modelContainer(container)
            #else
            content().buttonStyle(.glass).modelContainer(container)
            #endif
        case .failure(let error):
            ContentUnavailableView {
                Label("Unable to Open Local Data", systemImage: "externaldrive.badge.exclamationmark")
            } description: {
                Text("Your existing data has not been deleted. Quit Planora and check your backup before trying again.")
                Text(error.localizedDescription)
            }
        }
    }

#if os(macOS)
    @StateObject private var softwareUpdater = MacSoftwareUpdater.shared

    var body: some Scene {
        WindowGroup(id: "main") {
            storedContent { ContentView(store: store).background(MacMainWindowLifecycle()) }
        }
        .defaultSize(width: 1180, height: 760)
        .windowToolbarStyle(.unified)
        .commands {
            ToolbarCommands()
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    softwareUpdater.checkForUpdates()
                }
                .disabled(!softwareUpdater.canCheckForUpdates)
            }
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "New Task")) {
                    NotificationCenter.default.post(name: .planoraCreateTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            storedContent { MacSettingsView(store: store) }
                .frame(width: 620, height: 520)
        }

        MenuBarExtra {
            storedContent { MacMenuBarView(store: store) }
        } label: {
            Image(nsImage: PlanoraMenuBarIcon.image)
                .accessibilityLabel("Planora")
        }
        .menuBarExtraStyle(.window)
    }
#else
    var body: some Scene {
        WindowGroup {
            storedContent { ContentView(store: store) }
        }
    }
#endif
}

#if os(macOS)
extension Notification.Name {
    static let planoraCreateTask = Notification.Name("planora.create-task")
}
#endif
