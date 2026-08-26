import SwiftUI

#if os(macOS)
struct MacSettingsView: View {
    @Bindable var store: PlanoraStore

    var body: some View {
        TabView {
            Tab(String(localized: "General"), systemImage: "gearshape") {
                Form {
                    Section(String(localized: "Profile")) {
                        TextField(String(localized: "Name"), text: Binding(
                            get: { store.userName },
                            set: { store.updateUserName($0) }
                        ))
                        Picker(String(localized: "Curriculum"), selection: Binding(
                            get: { store.curriculum },
                            set: { store.selectCurriculum($0) }
                        )) {
                            ForEach(Curriculum.allCases) { Text($0.title).tag($0) }
                        }
                    }

                    Section(String(localized: "About")) {
                        LabeledContent(String(localized: "App"), value: "Planora")
                        LabeledContent(String(localized: "Version"), value: "1.6.0")
                    }
                }
                .formStyle(.grouped)
                .padding()
            }

            Tab(String(localized: "Tasks"), systemImage: "checklist") {
                Form {
                    Section(String(localized: "Task Display")) {
                        Picker(String(localized: "Density"), selection: Binding(
                            get: { store.taskDisplaySettings.density },
                            set: { value in store.updateTaskDisplay { $0.density = value } }
                        )) {
                            ForEach(PlanoraTaskDensity.allCases) { Text($0.title).tag($0) }
                        }
                        Picker(String(localized: "Sort"), selection: Binding(
                            get: { store.taskDisplaySettings.sortOrder },
                            set: { value in store.updateTaskDisplay { $0.sortOrder = value } }
                        )) {
                            ForEach(PlanoraTaskSortOrder.allCases) { Text($0.title).tag($0) }
                        }
                        Toggle(String(localized: "Show Completed Tasks"), isOn: Binding(
                            get: { store.taskDisplaySettings.showsCompletedTasks },
                            set: { value in store.updateTaskDisplay { $0.showsCompletedTasks = value } }
                        ))
                    }
                }
                .formStyle(.grouped)
                .padding()
            }

            Tab(String(localized: "ManageBac"), systemImage: "building.columns") {
                Form {
                    Section(String(localized: "Connection")) {
                        if let snapshot = ManageBacConnectionStorage.load() {
                            LabeledContent(String(localized: "Status"), value: String(localized: "Connected"))
                            LabeledContent(String(localized: "School"), value: snapshot.schoolHost)
                            LabeledContent(String(localized: "Last Sync"), value: snapshot.lastSyncDate.formatted(date: .abbreviated, time: .shortened))
                        } else {
                            LabeledContent(String(localized: "Status"), value: String(localized: "Not Connected"))
                        }
                        Text(String(localized: "Use the Courses workspace to connect or sync ManageBac."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .formStyle(.grouped)
                .padding()
            }
        }
        .padding(.top, 8)
    }
}
#endif
