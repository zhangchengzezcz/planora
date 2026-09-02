import SwiftData
import SwiftUI

#if os(macOS)
struct MacSettingsView: View {
    @Bindable var store: PlanoraStore
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @Query(sort: \PlanoraCourse.displayName) private var courses: [PlanoraCourse]
    @Query(sort: \PlanoraUnit.title) private var units: [PlanoraUnit]
    @Query(sort: \PlanoraTopic.title) private var topics: [PlanoraTopic]
    @Query(sort: \PlanoraAssessment.date, order: .reverse) private var assessments: [PlanoraAssessment]
    @State private var backupDocument = TaskBackupDocument()
    @State private var isShowingBackupExporter = false
    @State private var isShowingBackupImporter = false
    @State private var pendingImportPreview: TaskImportPreview?
    @State private var isShowingImportOptions = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var isShowingAlert = false

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
                        LabeledContent(String(localized: "Version"), value: appVersion)
                    }
                }
                .formStyle(.grouped)
                .padding()
            }

            Tab(String(localized: "Appearance"), systemImage: "paintpalette") {
                Form {
                    Section(String(localized: "Display Mode")) {
                        Picker(String(localized: "Display Mode"), selection: appearanceBinding(\.displayMode)) {
                            ForEach(PlanoraDisplayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section(String(localized: "Accent Color")) {
                        Picker(String(localized: "Accent Color"), selection: appearanceBinding(\.accent)) {
                            ForEach(PlanoraAccent.allCases) { accent in
                                Label(accent.title, systemImage: "circle.fill")
                                    .foregroundStyle(accent.color)
                                    .tag(accent)
                            }
                        }
                    }

                    Section {
                        Button(String(localized: "Reset Appearance"), systemImage: "arrow.counterclockwise") {
                            store.resetAppearance()
                        }
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
                        Toggle(String(localized: "Show Progress Percentage"), isOn: Binding(
                            get: { store.taskDisplaySettings.showsProgressPercentage },
                            set: { value in store.updateTaskDisplay { $0.showsProgressPercentage = value } }
                        ))
                        Toggle(String(localized: "Show Task Notes"), isOn: Binding(
                            get: { store.taskDisplaySettings.showsNotes },
                            set: { value in store.updateTaskDisplay { $0.showsNotes = value } }
                        ))
                    }

                    Section {
                        Button(String(localized: "Reset Task Display"), systemImage: "arrow.counterclockwise") {
                            store.resetTaskDisplay()
                        }
                    }
                }
                .formStyle(.grouped)
                .padding()
            }

            Tab(String(localized: "Data"), systemImage: "externaldrive") {
                Form {
                    Section(String(localized: "Task Storage")) {
                        LabeledContent(
                            String(localized: "Tasks"),
                            value: PlanoraLocalization.format(String(localized: "task_count_format"), tasks.count)
                        )
                        Button(String(localized: "Export Backup"), systemImage: "square.and.arrow.up") {
                            prepareBackupExport()
                        }
                        Button(String(localized: "Import Backup"), systemImage: "square.and.arrow.down") {
                            isShowingBackupImporter = true
                        }
                        if AutomaticTaskBackup.isAvailable {
                            Button(String(localized: "Restore Automatic Backup"), systemImage: "clock.arrow.circlepath") {
                                restoreAutomaticBackup()
                            }
                        }
                    }

                    Section {
                        Text(String(localized: "Backups stay under your control and are saved only where you choose."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
        .frame(minWidth: 620, minHeight: 480)
        .fileExporter(
            isPresented: $isShowingBackupExporter,
            document: backupDocument,
            contentType: TaskBackupDocument.backupType,
            defaultFilename: backupFileName
        ) { result in
            switch result {
            case .success:
                presentAlert(
                    title: String(localized: "Backup Saved"),
                    message: String(localized: "Your task backup has been saved to the location you chose.")
                )
            case .failure(let error):
                presentAlert(
                    title: String(localized: "Backup Failed"),
                    message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
                )
            }
        }
        .fileImporter(
            isPresented: $isShowingBackupImporter,
            allowedContentTypes: TaskBackupDocument.readableContentTypes
        ) { result in
            importBackup(from: result)
        }
        .confirmationDialog(
            String(localized: "Import Backup"),
            isPresented: $isShowingImportOptions,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Skip Duplicates")) { performImport(strategy: .skipDuplicates) }
            Button(String(localized: "Overwrite Matching Tasks")) { performImport(strategy: .overwriteDuplicates) }
            Button(String(localized: "Import All as New")) { performImport(strategy: .importAsNew) }
            Button(String(localized: "Cancel"), role: .cancel) { pendingImportPreview = nil }
        } message: {
            if let preview = pendingImportPreview {
                Text(PlanoraLocalization.format(
                    String(localized: "backup_import_preview_format"),
                    preview.tasks.count,
                    preview.duplicateCount
                ))
            }
        }
        .alert(alertTitle, isPresented: $isShowingAlert) {
            Button(String(localized: "OK"), role: .cancel) { }
        } message: {
            Text(alertMessage)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.6.2"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "12"
        return "\(version) (\(build))"
    }

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "Planora-Task-Backup-\(formatter.string(from: Date())).json"
    }

    private func appearanceBinding<Value>(_ keyPath: WritableKeyPath<PlanoraAppearanceSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.appearanceSettings[keyPath: keyPath] },
            set: { value in store.updateAppearance { $0[keyPath: keyPath] = value } }
        )
    }

    private func prepareBackupExport() {
        do {
            backupDocument = TaskBackupDocument(
                text: try TaskBackupCodec.json(
                    for: tasks,
                    courses: courses,
                    units: units,
                    topics: topics,
                    assessments: assessments
                )
            )
            isShowingBackupExporter = true
        } catch {
            presentAlert(
                title: String(localized: "Backup Failed"),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func importBackup(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            pendingImportPreview = try TaskBackupImporter.preview(
                from: url,
                existingTasks: tasks,
                existingCourses: courses,
                existingUnits: units
            )
            isShowingImportOptions = true
        } catch {
            presentAlert(
                title: TaskBackupError.importFailureTitle(for: error),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func performImport(strategy: TaskImportStrategy) {
        guard let preview = pendingImportPreview else { return }
        do {
            let result = try TaskBackupImporter.importTasks(
                preview,
                strategy: strategy,
                existingTasks: tasks,
                existingCourses: courses,
                existingUnits: units,
                existingTopics: topics,
                existingAssessments: assessments,
                into: modelContext
            )
            PlanoraTaskPersistence.reconcile(fallbackTasks: tasks, in: modelContext)
            pendingImportPreview = nil
            presentAlert(
                title: String(localized: "Import Complete"),
                message: PlanoraLocalization.format(
                    String(localized: "backup_import_result_format"),
                    result.importedCount,
                    result.skippedCount
                )
            )
        } catch {
            pendingImportPreview = nil
            presentAlert(
                title: TaskBackupError.importFailureTitle(for: error),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func restoreAutomaticBackup() {
        do {
            let content = try AutomaticTaskBackup.content()
            let existingIDs = Set(tasks.map(\.id))
            pendingImportPreview = TaskImportPreview(
                tasks: content.tasks,
                courses: content.courses,
                units: content.units,
                topics: content.topics,
                assessments: content.assessments,
                duplicateCount: content.tasks.filter { existingIDs.contains($0.id) }.count
            )
            isShowingImportOptions = true
        } catch {
            presentAlert(
                title: String(localized: "Restore Failed"),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func presentAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        isShowingAlert = true
    }
}
#endif
