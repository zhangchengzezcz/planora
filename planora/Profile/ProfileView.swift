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
            L("导入备份", "Import Backup"),
            isPresented: $isShowingImportOptions,
            titleVisibility: .visible
        ) {
            Button(L("跳过重复任务", "Skip Duplicates")) {
                performImport(strategy: .skipDuplicates)
            }
            Button(L("覆盖相同任务", "Overwrite Matching Tasks")) {
                performImport(strategy: .overwriteDuplicates)
            }
            Button(L("全部作为新任务导入", "Import All as New")) {
                performImport(strategy: .importAsNew)
            }
            Button(L("取消", "Cancel"), role: .cancel) {
                pendingImportPreview = nil
            }
        } message: {
            if let preview = pendingImportPreview {
                Text(LF("backup_import_preview_format", preview.tasks.count, preview.duplicateCount))
            }
        }
        .alert(backupAlertTitle, isPresented: $isShowingBackupAlert) {
            Button(L("好", "OK"), role: .cancel) { }
        } message: {
            Text(backupAlertMessage)
        }
    }

    // MARK: - Page Sections

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L("我的", "Me"))
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(Color.planoraInk)
                .padding(.top, 18)

            GlassPanel {
                HStack(spacing: 16) {
                    PlanoraLogoMark(size: 58)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(store.userName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.planoraInk)

                        Text("\(store.curriculum.badge) \(L("学习空间", "Learning Space"))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
            }
        }
    }

    private var profileSettingsSection: some View {
        DashboardSection(title: L("个人资料", "Profile")) {
            VStack(spacing: 0) {
                NavigationLink {
                    NameEditView(store: store)
                } label: {
                    SettingsRow(icon: "person.crop.circle", title: L("姓名", "Name"), value: store.userName, showsChevron: true)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
                NavigationLink {
                    CurriculumEditView(store: store)
                } label: {
                    SettingsRow(icon: store.curriculum.symbol, title: L("课程体系", "Curriculum"), value: store.curriculum.badge, showsChevron: true)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
                NavigationLink {
                    SubjectEditView(store: store)
                } label: {
                    SettingsRow(icon: "book.pages", title: L("我的科目", "My Subjects"), value: "\(store.selectedSubjectTitles.count)", showsChevron: true)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 52)
                SettingsRow(icon: "gearshape", title: L("设置", "Settings"), value: L("默认", "Default"))
            }
        }
    }

    private var taskStorageSection: some View {
        DashboardSection(title: L("任务保存", "Task Storage")) {
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
            DashboardSection(title: L("当前科目", "Current Subjects")) {
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

                    Divider().padding(.leading, 54)

                    NavigationLink {
                        SubjectEditView(store: store)
                    } label: {
                        SettingsRow(
                            icon: "slider.horizontal.3",
                            title: L("编辑科目", "Edit Subjects"),
                            value: "",
                            showsChevron: true
                        )
                    }
                    .buttonStyle(.plain)
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
                title: L("备份失败", "Backup Failed"),
                message: LF("backup_failure_format", error.localizedDescription)
            )
        }
    }

    private func handleBackupExport(_ result: Result<URL, Error>) {
        switch result {
        case .success:
            presentBackupAlert(
                title: L("备份已保存", "Backup Saved"),
                message: L("任务备份已经保存到你选择的位置。", "Your task backup has been saved to the location you chose.")
            )
        case .failure(let error):
            presentBackupAlert(
                title: L("备份失败", "Backup Failed"),
                message: LF("backup_failure_format", error.localizedDescription)
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
                message: LF("backup_failure_format", error.localizedDescription)
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
            let refreshedTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? tasks
            Task { await TaskReminderScheduler.reconcile(tasks: refreshedTasks) }
            pendingImportPreview = nil
            presentBackupAlert(
                title: L("导入完成", "Import Complete"),
                message: LF("backup_import_result_format", result.importedCount, result.skippedCount)
            )
        } catch {
            pendingImportPreview = nil
            presentBackupAlert(
                title: TaskBackupError.importFailureTitle(for: error),
                message: LF("backup_failure_format", error.localizedDescription)
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
                title: L("恢复失败", "Restore Failed"),
                message: LF("backup_failure_format", error.localizedDescription)
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

                Text(LF("subject_task_count_format", taskCount))
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
                    Text(L("编辑姓名", "Edit Name"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.planoraInk)

                    Text(L("修改后，主页问候和个人资料会同步更新。", "Update your name here. The home greeting and profile will stay in sync."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 18)

                DashboardSection(title: L("显示名称", "Display Name")) {
                    TextField(L("输入你的姓名", "Enter your name"), text: $nameDraft)
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
                    title: L("保存姓名", "Save Name"),
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
                    Text(L("课程体系", "Curriculum"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.planoraInk)

                    Text(L("选择与你当前学习内容匹配的课程体系。", "Choose the curriculum that matches your current study plan."))
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
        .alert(L("确认切换课程？", "Switch Curriculum?"), isPresented: $isShowingCurriculumSwitchConfirmation, presenting: pendingCurriculum) { curriculum in
            Button(L("确认切换", "Switch"), role: .destructive) {
                switchCurriculum(to: curriculum)
            }

            Button(L("取消", "Cancel"), role: .cancel) {
                pendingCurriculum = nil
            }
        } message: { _ in
            Text(L("切换课程后会清空当前课程体系内已创建的任务，并将科目重置为新课程体系的默认必选项。", "Switching curriculum deletes existing tasks for the current curriculum and resets subjects to the new curriculum defaults."))
        }
    }

    private func requestCurriculumSwitch(to curriculum: Curriculum) {
        guard store.curriculum != curriculum else { return }
        pendingCurriculum = curriculum
        isShowingCurriculumSwitchConfirmation = true
    }

    private func switchCurriculum(to curriculum: Curriculum) {
        // Switching curricula is destructive by product design: the new curriculum
        // starts from its default required subjects, and existing tasks are removed.
        let taskIDs = tasks.map(\.id)
        AutomaticTaskBackup.save(tasks: tasks)
        for task in tasks {
            modelContext.delete(task)
        }

        try? modelContext.save()
        Task { await TaskReminderScheduler.removeRequests(forTaskIDs: taskIDs) }
        store.selectCurriculum(curriculum)
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
                    Text(L("编辑科目", "Edit Subjects"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.planoraInk)

                    Text(LF("curriculum_subjects_format", store.curriculum.title))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                DashboardSection(title: L("科目", "Subjects")) {
                    SubjectPicker(store: store, columns: columns)
                    .padding(18)
                }

                DashboardSection(title: L("额外学习", "Extra Learning")) {
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

                    Text(L("切换课程体系前请注意", "Before Changing Curriculum"))
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Spacer()
                }

                Text(L("切换后，科目会根据新的课程体系重置为默认必选项；已创建的任务将不会保留。", "Changing curriculum resets subjects to the new curriculum defaults; existing tasks will not be kept."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    MiniStatusPill(title: L("科目重置", "Subjects Reset"), tint: .planoraBlue)
                    MiniStatusPill(title: L("任务不保留", "Tasks Removed"), tint: .red)
                    MiniStatusPill(title: L("备份任务", "Back Up Tasks"), tint: .planoraAmber)
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
                    Text(L("任务备份", "Task Backup"))
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Text(LF("task_backup_count_format", taskCount))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Text(L("保存为 JSON 备份文件，或导入并选择如何处理重复任务。", "Save a JSON backup file, or import one and choose how matching tasks are handled."))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            BackupShareHint()

            HStack(spacing: 10) {
                BackupActionButton(
                    title: L("保存备份", "Save Backup"),
                    systemImage: "square.and.arrow.down",
                    tint: .planoraBlue,
                    action: onExport
                )

                BackupActionButton(
                    title: L("导入备份", "Import Backup"),
                    systemImage: "square.and.arrow.up",
                    tint: .planoraGreen,
                    action: onImport
                )
            }


            Button(action: onRestoreAutomatic) {
                Label(L("恢复最近自动备份", "Restore Latest Automatic Backup"), systemImage: "clock.arrow.circlepath")
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

            Text(L("也可以把 JSON 文件直接通过系统分享给 Planora，App 会自动打开并导入 JSON 备份。", "You can also share the JSON file directly to Planora from the system share sheet. The app opens and imports the JSON backup automatically."))
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
