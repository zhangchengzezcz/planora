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

#if os(macOS)
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .modelContainer(for: PlanoraSchema.models)
        .defaultSize(width: 1180, height: 760)
        .commands {
            ToolbarCommands()
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "New Task")) {
                    NotificationCenter.default.post(name: .planoraCreateTask, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }

        Settings {
            MacSettingsView(store: store)
                .frame(width: 620, height: 520)
        }
        .modelContainer(for: PlanoraSchema.models)
    }
#else
    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
        }
        .modelContainer(for: PlanoraSchema.models)
    }
#endif
}

private enum PlanoraSchema {
    static let models: [any PersistentModel.Type] = [
        PlanoraTask.self,
        PlanoraCourse.self,
        PlanoraUnit.self,
        PlanoraTeacher.self,
        PlanoraMessage.self,
        PlanoraScheduleEvent.self
    ]
}

#if os(macOS)
extension Notification.Name {
    static let planoraCreateTask = Notification.Name("planora.create-task")
}
#endif
