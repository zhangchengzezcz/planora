import Foundation
import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var backupDocument = TaskBackupDocument()
    @State private var isShowingBackupExporter = false
    @State private var isShowingBackupImporter = false
    @State private var backupAlertTitle = ""
    @State private var backupAlertMessage = ""
    @State private var isShowingBackupAlert = false
    @State private var pendingImportPreview: TaskImportPreview?
    @State private var isShowingImportOptions = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                profileHeader
                profileSettingsSection
                taskStorageSection
                currentSubjectsSection
            }
            .padding(.top, 2)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .safeAreaBar(edge: .top, spacing: 0) {
            profileTitle
        }
        .scrollEdgeEffectStyle(.automatic, for: .top)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
        .fileExporter(
            isPresented: $isShowingBackupExporter,
            document: backupDocument,
            contentType: TaskBackupDocument.backupType,
            defaultFilename: backupFileName
        ) { result in
            handleBackupExport(result)
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
            Button(String(localized: "Skip Duplicates")) {
                performImport(strategy: .skipDuplicates)
            }
            Button(String(localized: "Overwrite Matching Tasks")) {
                performImport(strategy: .overwriteDuplicates)
            }
            Button(String(localized: "Import All as New")) {
                performImport(strategy: .importAsNew)
            }
            Button(String(localized: "Cancel"), role: .cancel) {
                pendingImportPreview = nil
            }
        } message: {
            if let preview = pendingImportPreview {
                Text(PlanoraLocalization.format(String(localized: "backup_import_preview_format"), preview.tasks.count, preview.duplicateCount))
            }
        }
        .alert(backupAlertTitle, isPresented: $isShowingBackupAlert) {
            Button(String(localized: "OK"), role: .cancel) { }
        } message: {
            Text(backupAlertMessage)
        }
    }

    // MARK: - Page Sections

    private var profileTitle: some View {
        Text(String(localized: "Me"))
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(Color.planoraInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
            .padding(.top, 18)
            .padding(.bottom, 18)
    }

    private var profileHeader: some View {
        GlassPanel {
            HStack(spacing: 16) {
                PlanoraLogoMark(size: 58)

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.userName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(verbatim: "\(store.curriculum.badge) \(String(localized: "Learning Space"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
    }

    private var profileSettingsSection: some View {
        DashboardSection(title: String(localized: "Profile")) {
            VStack(spacing: 0) {
                NavigationLink {
                    NameEditView(store: store)
                } label: {
                    SettingsRow(icon: "person.crop.circle", title: String(localized: "Name"), value: store.userName, showsChevron: true)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
                NavigationLink {
                    CurriculumEditView(store: store)
                } label: {
                    SettingsRow(icon: store.curriculum.symbol, title: String(localized: "Curriculum"), value: store.curriculum.badge, showsChevron: true)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
                NavigationLink {
                    SubjectEditView(store: store)
                } label: {
                    SettingsRow(icon: "book.pages", title: String(localized: "My Subjects"), value: "\(store.selectedSubjectTitles.count)", showsChevron: true)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
                NavigationLink {
                    SettingsHomeView(store: store)
                } label: {
                    SettingsRow(
                        icon: "gearshape.fill",
                        title: String(localized: "Settings"),
                        value: "",
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var taskStorageSection: some View {
        DashboardSection(title: String(localized: "Task Storage")) {
            TaskBackupCard(
                taskCount: tasks.count,
                onExport: prepareBackupExport,
                onImport: { isShowingBackupImporter = true },
                canRestoreAutomatic: AutomaticTaskBackup.isAvailable,
                onRestoreAutomatic: restoreAutomaticBackup
            )
            .padding(18)
        }
    }

    @ViewBuilder
    private var currentSubjectsSection: some View {
        let subjects = store.selectedSubjectTitles + store.selectedExtraLearningTitles

        if !subjects.isEmpty {
            DashboardSection(title: String(localized: "Current Subjects")) {
                VStack(spacing: 0) {
                    ForEach(Array(subjects.enumerated()), id: \.offset) { index, subject in
                        NavigationLink {
                            SubjectDetailView(store: store, subject: subject)
                        } label: {
                            SubjectProfileRow(
                                subject: subject,
                                taskCount: tasks.filter { $0.subject == subject }.count
                            )
                        }
                        .buttonStyle(.plain)

                        if index != subjects.indices.last {
                            Divider().padding(.leading, 54)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Backup Actions

    private var backupFileName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmm"
        return "Planora-Task-Backup-\(formatter.string(from: Date())).json"
    }

    private func prepareBackupExport() {
        do {
            backupDocument = TaskBackupDocument(text: try TaskBackupCodec.json(for: tasks))
            isShowingBackupExporter = true
        } catch {
            presentBackupAlert(
                title: String(localized: "Backup Failed"),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func handleBackupExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            presentBackupAlert(
                title: String(localized: "Backup Saved"),
                message: String(localized: "Your task backup has been saved to the location you chose.")
            )
        case .failure(let error):
            presentBackupAlert(
                title: String(localized: "Backup Failed"),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func importBackup(from result: Result<URL, Error>) {
        do {
            let url = try result.get()
            pendingImportPreview = try TaskBackupImporter.preview(from: url, existingTasks: tasks)
            isShowingImportOptions = true
        } catch {
            presentBackupAlert(
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
                into: modelContext
            )
            PlanoraTaskPersistence.reconcile(fallbackTasks: tasks, in: modelContext)
            pendingImportPreview = nil
            presentBackupAlert(
                title: String(localized: "Import Complete"),
                message: PlanoraLocalization.format(String(localized: "backup_import_result_format"), result.importedCount, result.skippedCount)
            )
        } catch {
            pendingImportPreview = nil
            presentBackupAlert(
                title: TaskBackupError.importFailureTitle(for: error),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func restoreAutomaticBackup() {
        do {
            let backupTasks = try AutomaticTaskBackup.tasks()
            let existingIDs = Set(tasks.map(\.id))
            let duplicateCount = backupTasks.filter { existingIDs.contains($0.id) }.count
            pendingImportPreview = TaskImportPreview(tasks: backupTasks, duplicateCount: duplicateCount)
            isShowingImportOptions = true
        } catch {
            presentBackupAlert(
                title: String(localized: "Restore Failed"),
                message: PlanoraLocalization.format(String(localized: "backup_failure_format"), error.localizedDescription)
            )
        }
    }

    private func presentBackupAlert(title: String, message: String) {
        backupAlertTitle = title
        backupAlertMessage = message
        isShowingBackupAlert = true
    }
}

private struct SubjectProfileRow: View {
    let subject: String
    let taskCount: Int

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.closed.fill")
                .font(.headline)
                .foregroundStyle(Color.planoraDeepGreen)
                .frame(width: 38, height: 38)
                .background(Color.planoraGreen.opacity(0.12), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(PlanoraFormat.subjectDisplayName(subject))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(PlanoraLocalization.format(String(localized: "subject_task_count_format"), taskCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}

// MARK: - Detail Editors

private struct NameEditView: View {
    @Environment(\.dismiss) private var dismiss
    let store: PlanoraStore
    @State private var nameDraft: String
    @FocusState private var isNameFocused: Bool

    init(store: PlanoraStore) {
        self.store = store
        _nameDraft = State(initialValue: store.userName)
    }

    private var trimmedName: String {
        nameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedName.isEmpty
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Edit Name"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(String(localized: "Update your name here. The home greeting and profile will stay in sync."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)

                DashboardSection(title: String(localized: "Display Name")) {
                    TextField(String(localized: "Enter your name"), text: $nameDraft)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.planoraInk)
                        .textFieldStyle(.plain)
                        .focused($isNameFocused)
                        .submitLabel(.done)
                        .onSubmit(saveName)
                        .padding(18)
                        .frame(minHeight: 64)
                }

                PlanoraPrimaryButton(
                    title: String(localized: "Save Name"),
                    systemImage: "checkmark",
                    isDisabled: !canSave,
                    action: saveName
                )
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
        .task {
            isNameFocused = true
        }
    }

    private func saveName() {
        guard canSave else { return }
        store.updateUserName(trimmedName)
        dismiss()
    }
}

private struct SettingsHomeView: View {
    let store: PlanoraStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Settings"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(String(localized: "Manage Planora appearance and task-list preferences."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                DashboardSection(title: String(localized: "Preferences")) {
                    VStack(spacing: 0) {
                        NavigationLink {
                            AppearanceSettingsView(store: store)
                        } label: {
                            SettingsRow(
                                icon: "paintpalette.fill",
                                title: String(localized: "Appearance"),
                                value: store.appearanceSettings.summary,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)

                        Divider().padding(.leading, 52)

                        NavigationLink {
                            TaskDisplaySettingsView(store: store)
                        } label: {
                            SettingsRow(
                                icon: "list.bullet.rectangle.portrait.fill",
                                title: String(localized: "Task Display"),
                                value: store.taskDisplaySettings.summary,
                                showsChevron: true
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }
}

private struct AppearanceSettingsView: View {
    let store: PlanoraStore

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Appearance"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(String(localized: "Customize how Planora looks on this device."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                AppearanceControlSection(title: String(localized: "Color Theme")) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PlanoraColorTheme.allCases) { theme in
                            ColorThemeButton(
                                theme: theme,
                                isSelected: theme.matches(store.appearanceSettings)
                            ) {
                                store.updateAppearance {
                                    $0.backgroundStyle = theme.backgroundStyle
                                    $0.accent = theme.accent
                                }
                            }
                        }
                    }
                }

                AppearanceControlSection(title: String(localized: "Display Mode")) {
                    Picker(String(localized: "Display Mode"), selection: binding(\.displayMode)) {
                        ForEach(PlanoraDisplayMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                AppearanceControlSection(title: String(localized: "Background")) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(PlanoraBackgroundStyle.allCases) { style in
                            BackgroundStyleButton(
                                style: style,
                                isSelected: store.appearanceSettings.backgroundStyle == style
                            ) {
                                store.updateAppearance { $0.backgroundStyle = style }
                            }
                        }
                    }
                }

                AppearanceControlSection(title: String(localized: "Accent Color")) {
                    HStack(spacing: 18) {
                        ForEach(PlanoraAccent.allCases) { accent in
                            AccentColorButton(
                                accent: accent,
                                isSelected: store.appearanceSettings.accent == accent
                            ) {
                                store.updateAppearance { $0.accent = accent }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    store.resetAppearance()
                } label: {
                    Label(String(localized: "Reset Appearance"), systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
                .tint(store.appearanceSettings.accent.color)
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PlanoraAppearanceSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.appearanceSettings[keyPath: keyPath] },
            set: { value in
                store.updateAppearance { $0[keyPath: keyPath] = value }
            }
        )
    }

}

private struct TaskDisplaySettingsView: View {
    let store: PlanoraStore

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 26) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Task Display"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(String(localized: "These options change the task list without editing task data."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                AppearanceControlSection(title: String(localized: "Task Appearance")) {
                    Picker(String(localized: "Task Appearance"), selection: binding(\.density)) {
                        ForEach(PlanoraTaskDensity.allCases) { density in
                            Text(density.title).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                AppearanceControlSection(title: String(localized: "Default Sorting")) {
                    Picker(String(localized: "Default Sorting"), selection: binding(\.sortOrder)) {
                        ForEach(PlanoraTaskSortOrder.allCases) { order in
                            Text(order.title).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .buttonStyle(.bordered)
                }

                AppearanceControlSection(title: String(localized: "Visible Content")) {
                    VStack(spacing: 14) {
                        Toggle(String(localized: "Show Completed Tasks"), isOn: binding(\.showsCompletedTasks))
                        Divider()
                        Toggle(String(localized: "Show Progress Percentage"), isOn: binding(\.showsProgressPercentage))
                        Divider()
                        Toggle(String(localized: "Show Task Notes"), isOn: binding(\.showsNotes))
                    }
                    .font(.subheadline.weight(.semibold))
                }

                Button {
                    store.resetTaskDisplay()
                } label: {
                    Label(String(localized: "Reset Task Display"), systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.bordered)
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<PlanoraTaskDisplaySettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.taskDisplaySettings[keyPath: keyPath] },
            set: { value in
                store.updateTaskDisplay { $0[keyPath: keyPath] = value }
            }
        )
    }
}

private struct AppearanceControlSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Color.planoraInk)
            content
        }
    }
}

private struct BackgroundStyleButton: View {
    let style: PlanoraBackgroundStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                style.swatch
                    .frame(height: 68)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.planoraOnAccent)
                                .padding(8)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color.planoraInk.opacity(0.55) : Color.planoraControlStroke, lineWidth: isSelected ? 2 : 1)
                    }

                Text(style.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ColorThemeButton: View {
    let theme: PlanoraColorTheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                theme.swatch
                    .frame(height: 58)
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.planoraOnAccent)
                                .padding(8)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(isSelected ? Color.planoraInk.opacity(0.55) : Color.planoraControlStroke, lineWidth: isSelected ? 2 : 1)
                    }

                Text(theme.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(theme.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AccentColorButton: View {
    let accent: PlanoraAccent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(accent.color)
                        .frame(width: 38, height: 38)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Color.planoraOnAccent)
                    }
                }

                Text(accent.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
            }
            .frame(minWidth: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accent.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct CurriculumEditView: View {
    @Environment(\.modelContext) private var modelContext
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var pendingCurriculum: Curriculum?
    @State private var isShowingCurriculumSwitchConfirmation = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Curriculum"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(String(localized: "Choose the curriculum that matches your current study plan."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)

                VStack(spacing: 14) {
                    ForEach(Curriculum.allCases) { curriculum in
                        CurriculumCard(
                            curriculum: curriculum,
                            isSelected: store.curriculum == curriculum
                        ) {
                            requestCurriculumSwitch(to: curriculum)
                        }
                    }
                }

                ChangeCurriculumCard()
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
        .alert(String(localized: "Switch Curriculum?"), isPresented: $isShowingCurriculumSwitchConfirmation, presenting: pendingCurriculum) { curriculum in
            Button(String(localized: "Switch"), role: .destructive) {
                switchCurriculum(to: curriculum)
            }

            Button(String(localized: "Cancel"), role: .cancel) {
                pendingCurriculum = nil
            }
        } message: { _ in
            Text(String(localized: "Switching curriculum deletes existing tasks for the current curriculum and resets subjects to the new curriculum defaults."))
        }
    }

    private func requestCurriculumSwitch(to curriculum: Curriculum) {
        guard store.curriculum != curriculum else { return }
        pendingCurriculum = curriculum
        isShowingCurriculumSwitchConfirmation = true
    }

    private func switchCurriculum(to curriculum: Curriculum) {
        PlanoraTaskOperations.switchCurriculum(
            to: curriculum,
            tasks: tasks,
            modelContext: modelContext,
            store: store
        )
        pendingCurriculum = nil
    }
}

private struct SubjectEditView: View {
    let store: PlanoraStore

    private let columns = [
        GridItem(.adaptive(minimum: 136), spacing: 12)
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "My Subjects"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(PlanoraLocalization.format(String(localized: "curriculum_subjects_format"), store.curriculum.title))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                DashboardSection(title: String(localized: "Subjects")) {
                    SubjectPicker(store: store, columns: columns)
                    .padding(18)
                }

                DashboardSection(title: String(localized: "Extra Learning")) {
                    ExtraLearningPicker(store: store, columns: columns)
                    .padding(18)
                }
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }
}

// MARK: - Profile Cards

private struct ChangeCurriculumCard: View {
    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.planoraAmber)

                    Text(String(localized: "Before Changing Curriculum"))
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Spacer()
                }

                Text(String(localized: "Changing curriculum resets subjects to the new curriculum defaults; existing tasks will not be kept."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    MiniStatusPill(title: String(localized: "Subjects Reset"), tint: .planoraBlue)
                    MiniStatusPill(title: String(localized: "Tasks Removed"), tint: .red)
                    MiniStatusPill(title: String(localized: "Back Up Tasks"), tint: .planoraAmber)
                }
            }
        }
    }
}

private struct TaskBackupCard: View {
    let taskCount: Int
    let onExport: () -> Void
    let onImport: () -> Void
    let canRestoreAutomatic: Bool
    let onRestoreAutomatic: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "externaldrive.badge.icloud")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.planoraBlue)
                    .frame(width: 40, height: 40)
                    .background(Color.planoraBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(String(localized: "Task Backup"))
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Text(PlanoraLocalization.format(String(localized: "task_backup_count_format"), taskCount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(String(localized: "Save a JSON backup file, or import one and choose how matching tasks are handled."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            BackupShareHint()

            HStack(spacing: 10) {
                BackupActionButton(
                    title: String(localized: "Save Backup"),
                    systemImage: "square.and.arrow.down",
                    tint: .planoraBlue,
                    action: onExport
                )

                BackupActionButton(
                    title: String(localized: "Import Backup"),
                    systemImage: "square.and.arrow.up",
                    tint: .planoraGreen,
                    action: onImport
                )
            }


            Button(action: onRestoreAutomatic) {
                Label(String(localized: "Restore Latest Automatic Backup"), systemImage: "clock.arrow.circlepath")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 42)
            }
            .buttonStyle(.bordered)
            .tint(Color.planoraAmber)
            .disabled(!canRestoreAutomatic)
        }
    }
}

private struct BackupShareHint: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "square.and.arrow.up")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.planoraAmber)
                .frame(width: 24, height: 24)

            Text(String(localized: "You can also share the JSON file directly to Planora from the system share sheet. The app opens and imports the JSON backup automatically."))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.planoraInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.planoraAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.planoraAmber.opacity(0.24), lineWidth: 1)
        )
    }
}

private struct BackupActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.bold))

                Text(title)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 12)
            .background(tint.opacity(0.12), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.24), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct FlowTagList: View {
    let items: [String]

    private let columns = [
        GridItem(.adaptive(minimum: 96), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(PlanoraFormat.subjectDisplayName(item))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.planoraTagFill, in: Capsule())
                    .overlay(Capsule().stroke(Color.planoraControlStroke, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
