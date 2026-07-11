import SwiftData
import SwiftUI

struct HomeDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    let store: PlanoraStore
    let onCreateRequested: () -> Void
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var pendingCurriculum: Curriculum?
    @State private var isShowingCurriculumSwitchConfirmation = false
    @State private var calendarMonthDate = Date()

    // MARK: - Task Queries

    private var activeTasks: [PlanoraTask] {
        sortedTasks.filter { !$0.isCompleted }
    }

    private var sortedTasks: [PlanoraTask] {
        tasks.sorted { lhs, rhs in
            if lhs.importance != rhs.importance {
                return lhs.importance > rhs.importance
            }

            switch (lhs.hasDeadline, rhs.hasDeadline) {
            case (true, true):
                if lhs.deadline != rhs.deadline {
                    return (lhs.deadline ?? .distantFuture) < (rhs.deadline ?? .distantFuture)
                }
            case (true, false):
                return true
            case (false, true):
                return false
            case (false, false):
                break
            }

            return lhs.createdDate < rhs.createdDate
        }
    }

    private var focusTask: PlanoraTask? {
        activeTasks.first
    }

    private var upcomingProgressTasks: [PlanoraTask] {
        Array(activeTasks.filter(\.tracksProgress).prefix(4))
    }

    private var upcomingTimelineItems: [PlanoraTask] {
        Array(activeTasks.filter { !$0.tracksProgress }.prefix(4))
    }

    private var taskCompletionSnapshot: TaskCompletionSnapshot {
        TaskCompletionSnapshot(
            title: L("本周", "This Week"),
            completed: weeklyTasks.filter { task in
                guard task.isCompleted else { return false }
                if let completedDate = task.completedDate {
                    return currentWeek.contains(completedDate)
                }
                return currentWeek.contains(task.deadline ?? task.createdDate)
            }.count,
            total: weeklyTasks.count,
            tint: .planoraGreen
        )
    }

    private var currentWeek: DateInterval {
        Calendar.current.dateInterval(of: .weekOfYear, for: Date())
            ?? DateInterval(start: Calendar.current.startOfDay(for: Date()), duration: 7 * 86_400)
    }

    private var weeklyTasks: [PlanoraTask] {
        tasks.filter { task in
            currentWeek.contains(task.deadline ?? task.createdDate)
                || task.completedDate.map(currentWeek.contains) == true
        }
    }

    private var completedThisWeekCount: Int {
        tasks.filter { task in
            guard task.isCompleted else { return false }
            if let completedDate = task.completedDate {
                return currentWeek.contains(completedDate)
            }
            return currentWeek.contains(task.deadline ?? task.createdDate)
        }.count
    }

    private var mostActiveSubject: String {
        let relevantTasks = tasks.filter { task in
            !task.isCompleted || task.completedDate.map(currentWeek.contains) == true
        }
        let counts = Dictionary(grouping: relevantTasks, by: \.subject).mapValues(\.count)
        return counts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return PlanoraFormat.subjectDisplayName(lhs.key) > PlanoraFormat.subjectDisplayName(rhs.key)
        }?.key ?? L("暂无", "None Yet")
    }

    private var upcomingSevenDayCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: 7, to: today) else { return 0 }

        return tasks.filter { task in
            guard !task.isCompleted, task.hasDeadline, let deadline = task.deadline else { return false }
            return deadline >= today && deadline < end
        }.count
    }

    private var overdueCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        return tasks.filter { task in
            guard !task.isCompleted, task.hasDeadline, let deadline = task.deadline else { return false }
            return deadline < today
        }.count
    }

    private var upcomingWorkloadLevel: LearningWorkloadLevel {
        switch upcomingSevenDayCount {
        case 0...2: .low
        case 3...5: .moderate
        default: .high
        }
    }

    private var subjectProgressSnapshots: [SubjectProgressSnapshot] {
        let grouped = Dictionary(grouping: tasks.filter(\.tracksProgress).map { task -> (String, Double, Color) in
            (task.subject.planoraDisplaySubjectName, task.progressFraction, task.type.tint)
        }, by: \.0)

        return grouped
            .map { subject, values in
                let average = values.map(\.1).reduce(0, +) / Double(values.count)
                let tint = values.first?.2 ?? .planoraBlue
                return SubjectProgressSnapshot(title: subject, value: average, tint: tint)
            }
            .sorted { $0.title < $1.title }
    }

    private var deadlineTasks: [PlanoraTask] {
        sortedTasks.filter { $0.hasDeadline && $0.deadline != nil }
    }

    // MARK: - View

    var body: some View {
        ScrollView(showsIndicators: false) {
            contentStack
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
        .onAppear {
            refreshScheduledWork()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { refreshScheduledWork() }
        }
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

    private func refreshScheduledWork() {
        for task in tasks {
            task.normalizeLegacyTaskType()
            task.normalizeCalendarDates()
        }
        try? modelContext.save()
        RecurringTaskEngine.ensureRollingSeries(tasks: tasks, in: modelContext)
        let refreshedTasks = (try? modelContext.fetch(FetchDescriptor<PlanoraTask>())) ?? tasks
        Task { await TaskReminderScheduler.reconcile(tasks: refreshedTasks) }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 18) {
            HomeHeader(store: store) { curriculum in
                requestCurriculumSwitch(to: curriculum)
            }

            PlanningDestinationStrip(store: store)

            taskOverviewSection
            learningProgressSection
            calendarPreviewSection
        }
        .padding(.top, 18)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private var taskOverviewSection: some View {
        if let focusTask {
            TodayFocusCard(store: store, task: focusTask)
            upcomingProgressSection
            upcomingTimelineSection
        } else if !tasks.isEmpty {
            AllTasksCompletedCard()
        } else {
            EmptyTasksCard(action: onCreateRequested)
        }
    }

    @ViewBuilder
    private var upcomingProgressSection: some View {
        if !upcomingProgressTasks.isEmpty {
            DashboardSection(title: L("即将到来的任务", "Upcoming Tasks")) {
                TaskList(store: store, tasks: upcomingProgressTasks)
            }
        }
    }

    @ViewBuilder
    private var upcomingTimelineSection: some View {
        if !upcomingTimelineItems.isEmpty {
            DashboardSection(title: L("时间与事件", "Dates and Events")) {
                TaskList(store: store, tasks: upcomingTimelineItems)
            }
        }
    }

    @ViewBuilder
    private var learningProgressSection: some View {
        if !tasks.isEmpty {
            DashboardSection(title: L("学习进度", "Learning Progress")) {
                VStack(alignment: .leading, spacing: 18) {
                    if !subjectProgressSnapshots.isEmpty {
                        ProgressGroupTitle(L("科目进度", "Subject Progress"))

                        ForEach(subjectProgressSnapshots) { snapshot in
                            ProgressSubjectRow(title: snapshot.title, value: snapshot.value, tint: snapshot.tint)
                        }

                        Divider()
                    }

                    ProgressGroupTitle(L("任务完成", "Task Completion"))
                    TaskCompletionRow(snapshot: taskCompletionSnapshot)

                    Divider()

                    LearningInsightsGrid(
                        completedThisWeek: completedThisWeekCount,
                        mostActiveSubject: PlanoraFormat.subjectDisplayName(mostActiveSubject),
                        upcomingWorkload: "\(upcomingWorkloadLevel.title) · \(LF("task_count_short_format", upcomingSevenDayCount))",
                        workloadTint: upcomingWorkloadLevel.tint,
                        overdueCount: overdueCount
                    )
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private var calendarPreviewSection: some View {
        if !deadlineTasks.isEmpty {
            DashboardSection(title: L("日历预览", "Calendar Preview")) {
                CalendarPreview(
                    store: store,
                    tasks: deadlineTasks,
                    monthDate: $calendarMonthDate
                )
                    .padding(18)
            }
        }
    }

    // MARK: - Curriculum Switching

    private func requestCurriculumSwitch(to curriculum: Curriculum) {
        guard store.curriculum != curriculum else { return }
        pendingCurriculum = curriculum
        isShowingCurriculumSwitchConfirmation = true
    }

    private func switchCurriculum(to curriculum: Curriculum) {
        // A curriculum switch starts from a clean task set so IB-only or IGCSE-only
        // work cannot leak into the newly selected programme.
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

// MARK: - Header

private struct HomeHeader: View {
    let store: PlanoraStore
    let onCurriculumSelected: (Curriculum) -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LF("home_hello_user_format", store.userName))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.planoraInk)

                Text(L("现在应该关注什么？", "What needs attention now?"))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Menu {
                ForEach(Curriculum.allCases) { curriculum in
                    Button {
                        onCurriculumSelected(curriculum)
                    } label: {
                        Label(curriculum.title, systemImage: curriculum.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(store.curriculum.badge)
                        .font(.subheadline.weight(.bold))

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(store.curriculum.tint)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.planoraGlassFill, in: Capsule())
                .glassEffect(.regular.tint(store.curriculum.tint.opacity(0.12)).interactive(), in: Capsule())
                .overlay(Capsule().stroke(Color.planoraGlassStroke, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Highlights

private struct TodayFocusCard: View {
    let store: PlanoraStore
    let task: PlanoraTask

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    TaskCompletionButton(task: task)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(L("当前重点", "Current Focus"))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.planoraBlue)
                            .textCase(.uppercase)

                        Text(task.title)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.planoraInk)

                        Text(task.subject.planoraDisplaySubjectName)
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 8) {
                        PriorityPill(priority: task.priority)

                        NavigationLink {
                            TaskDetailView(store: store, task: task)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Color.planoraBlue)
                                .frame(width: 36, height: 36)
                                .background(Color.planoraBlue.opacity(0.12), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(focusText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TaskStatusGrid(task: task)

                if task.tracksProgress, let progress = task.progressState.percentageValue {
                    ProgressView(value: progress)
                        .tint(task.type.tint)
                }
            }
        }
    }

    private var focusText: String {
        guard task.hasDeadline, let deadline = task.deadline else {
            return task.tracksProgress
                ? L("无截止日期。完成你的下一个里程碑。", "No deadline. Complete your next milestone.")
                : LF("focus_no_deadline_saved_format", task.type.title)
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: deadline)
        let days = calendar.dateComponents([.day], from: start, to: end).day ?? 0

        if days < 0 {
            return task.tracksProgress
                ? L("已逾期。完成你的下一个里程碑。", "Overdue. Complete your next milestone.")
                : LF("focus_date_passed_review_format", task.type.title)
        }

        if days == 0 {
            return task.tracksProgress
                ? L("今天截止。完成你的下一个里程碑。", "Due today. Complete your next milestone.")
                : LF("focus_today_remember_format", task.type.title)
        }

        return task.tracksProgress
            ? LF("focus_days_left_progress_format", days)
            : LF("focus_days_left_saved_format", days, task.type.title)
    }
}

// MARK: - Task Rows

private struct TaskList: View {
    let store: PlanoraStore
    let tasks: [PlanoraTask]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                TaskRow(store: store, task: task)

                if index != tasks.indices.last {
                    Divider().padding(.leading, 56)
                }
            }
        }
    }
}

private struct TaskRow: View {
    let store: PlanoraStore
    let task: PlanoraTask

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                TaskCompletionButton(task: task)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.headline)
                    .foregroundStyle(task.type.tint)
                    .frame(width: 42, height: 42)
                    .background(task.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)

                    Text(task.subject.planoraDisplaySubjectName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    PriorityPill(priority: task.priority)

                    NavigationLink {
                        TaskDetailView(store: store, task: task)
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                }
            }

            TaskStatusGrid(task: task)

            if task.tracksProgress, let progress = task.progressState.percentageValue {
                ProgressView(value: progress)
                    .tint(task.type.tint)
            }
        }
        .padding(18)
    }
}

private struct TaskStatusGrid: View {
    let task: PlanoraTask

    var body: some View {
        HStack(spacing: 10) {
            TaskStatusTile(label: L("截止日期", "Deadline"), value: deadlineText, tint: task.type.tint, isPrimary: true)
            if task.tracksProgress {
                TaskStatusTile(label: task.progressState.label, value: task.progressState.valueText, tint: task.type.tint)
            } else {
                TaskStatusTile(label: L("类型", "Type"), value: task.type.title, tint: task.type.tint)
            }
        }
    }

    private var deadlineText: String {
        guard task.hasDeadline, let deadline = task.deadline else {
            return L("无截止日期", "No deadline")
        }

        return PlanoraFormat.monthDay(deadline)
    }
}

private struct TaskStatusTile: View {
    let label: String
    let value: String
    let tint: Color
    let isPrimary: Bool

    init(label: String, value: String, tint: Color, isPrimary: Bool = false) {
        self.label = label
        self.value = value
        self.tint = tint
        self.isPrimary = isPrimary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(isPrimary ? Color.planoraInk : tint)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

// MARK: - Progress

private struct ProgressGroupTitle: View {
    let title: String

    init(_ title: String) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct EmptyTasksCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlassPanel(interactive: true) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title.weight(.bold))
                        .foregroundStyle(LinearGradient.planoraAccent)

                    Text(L("还没有任务", "No Tasks Yet"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(L("开始规划你的学习旅程。", "Start planning your learning journey."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text(L("点击这里创建第一个任务。", "Tap here to create your first task."))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.planoraDeepGreen)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L("创建第一个任务", "Create first task"))
    }
}

private struct AllTasksCompletedCard: View {
    var body: some View {
        GlassPanel {
            HStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Color.planoraGreen)
                    .frame(width: 50, height: 50)
                    .background(Color.planoraGreen.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(L("全部完成", "All Caught Up"))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(L("所有任务都已完成。准备好时，再开始下一段计划。", "Every task is complete. Start your next plan whenever you are ready."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct TaskCompletionRow: View {
    let snapshot: TaskCompletionSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(snapshot.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)

                Spacer()

                Text(snapshot.valueText)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(snapshot.tint)
            }

            ProgressView(value: snapshot.value)
                .tint(snapshot.tint)
        }
    }
}

private struct LearningInsightsGrid: View {
    let completedThisWeek: Int
    let mostActiveSubject: String
    let upcomingWorkload: String
    let workloadTint: Color
    let overdueCount: Int

    private let columns = [
        GridItem(.flexible(), spacing: 18),
        GridItem(.flexible(), spacing: 18)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            LearningInsight(
                title: L("本周完成", "Completed This Week"),
                value: "\(completedThisWeek)",
                systemImage: "checkmark.circle.fill",
                tint: .planoraGreen
            )

            LearningInsight(
                title: L("最活跃科目", "Most Active Subject"),
                value: mostActiveSubject,
                systemImage: "book.closed.fill",
                tint: .planoraBlue
            )

            LearningInsight(
                title: L("未来任务负载", "Upcoming Workload"),
                value: upcomingWorkload,
                systemImage: "calendar.badge.clock",
                tint: workloadTint
            )

            LearningInsight(
                title: L("已逾期", "Overdue"),
                value: "\(overdueCount)",
                systemImage: "exclamationmark.circle.fill",
                tint: overdueCount > 0 ? .red : .planoraGreen
            )
        }
    }
}

private enum LearningWorkloadLevel {
    case low
    case moderate
    case high

    var title: String {
        switch self {
        case .low: L("低", "Low")
        case .moderate: L("中等", "Moderate")
        case .high: L("高", "High")
        }
    }

    var tint: Color {
        switch self {
        case .low: .planoraGreen
        case .moderate: .planoraAmber
        case .high: .red
        }
    }
}

private struct LearningInsight: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.planoraInk)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 82, alignment: .topLeading)
    }
}

// MARK: - Calendar

private struct CalendarPreview: View {
    let store: PlanoraStore
    let tasks: [PlanoraTask]
    @Binding var monthDate: Date
    @State private var selectedDate: Date?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
    private var weekdays: [String] { PlanoraFormat.weekdays }

    private var monthTasks: [PlanoraTask] {
        tasks.filter { task in
            guard let deadline = task.deadline else { return false }
            return Calendar.current.isDate(deadline, equalTo: monthDate, toGranularity: .month)
        }
    }

    private var selectedTasks: [PlanoraTask] {
        guard let selectedDate else { return [] }
        return monthTasks
            .filter { task in
                guard let deadline = task.deadline else { return false }
                return Calendar.current.isDate(deadline, inSameDayAs: selectedDate)
            }
            .sorted { lhs, rhs in
                if lhs.isCompleted != rhs.isCompleted { return !lhs.isCompleted }
                if lhs.importance != rhs.importance { return lhs.importance > rhs.importance }
                return lhs.createdDate > rhs.createdDate
            }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            calendarHeader

            LazyVGrid(columns: columns, spacing: 8) {
                weekdayHeaders
                calendarCells
            }

            Divider()

            selectedDaySection
        }
        .onAppear(perform: selectInitialDate)
        .onChange(of: monthDate) { _, _ in
            selectInitialDate()
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlanoraFormat.monthYear(monthDate))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(LF("calendar_item_count_format", monthTasks.count))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                monthDate = Date()
                selectedDate = Date()
            } label: {
                Text(L("今天", "Today"))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.planoraDeepGreen)
                    .frame(minHeight: 34)
                    .padding(.horizontal, 9)
            }
            .buttonStyle(.plain)

            CalendarNavigationButton(
                systemImage: "chevron.left",
                accessibilityTitle: L("上个月", "Previous Month")
            ) {
                changeMonth(by: -1)
            }

            CalendarNavigationButton(
                systemImage: "chevron.right",
                accessibilityTitle: L("下个月", "Next Month")
            ) {
                changeMonth(by: 1)
            }
        }
    }

    @ViewBuilder
    private var weekdayHeaders: some View {
        ForEach(Array(weekdays.enumerated()), id: \.offset) { _, weekday in
            Text(weekday)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private var calendarCells: some View {
        ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
            if let date {
                CalendarDateButton(
                    date: date,
                    isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true,
                    isToday: Calendar.current.isDateInToday(date),
                    taskTints: taskTints(on: date)
                ) {
                    selectedDate = date
                }
            } else {
                Color.clear
                    .frame(height: 38)
            }
        }
    }

    @ViewBuilder
    private var selectedDaySection: some View {
        if let selectedDate {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(PlanoraFormat.monthDay(selectedDate))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Spacer()

                    Text(LF("task_count_short_format", selectedTasks.count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if selectedTasks.isEmpty {
                    Text(L("这一天没有截止任务。", "No deadlines on this day."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(selectedTasks.enumerated()), id: \.element.id) { index, task in
                            NavigationLink {
                                TaskDetailView(store: store, task: task)
                            } label: {
                                CalendarTaskRow(task: task)
                            }
                            .buttonStyle(.plain)

                            if index != selectedTasks.indices.last {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private var calendarDays: [Date?] {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
              let dayRange = calendar.range(of: .day, in: .month, for: monthDate) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyCount = (firstWeekday + 5) % 7
        let emptyDays = Array<Date?>(repeating: nil, count: leadingEmptyCount)
        let dates = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        return emptyDays + dates.map(Optional.some)
    }

    private func taskTints(on date: Date) -> [Color] {
        monthTasks
            .filter { task in
                guard let deadline = task.deadline else { return false }
                return Calendar.current.isDate(deadline, inSameDayAs: date)
            }
            .prefix(3)
            .map { $0.type.tint }
    }

    private func selectInitialDate() {
        let calendar = Calendar.current
        if calendar.isDate(Date(), equalTo: monthDate, toGranularity: .month) {
            selectedDate = Date()
            return
        }

        selectedDate = monthTasks
            .compactMap(\.deadline)
            .sorted()
            .first
            ?? calendar.dateInterval(of: .month, for: monthDate)?.start
    }

    private func changeMonth(by value: Int) {
        monthDate = Calendar.current.date(byAdding: .month, value: value, to: monthDate) ?? monthDate
    }
}

private struct CalendarNavigationButton: View {
    let systemImage: String
    let accessibilityTitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.planoraInk)
                .frame(width: 34, height: 34)
                .background(Color.planoraControlFill, in: Circle())
                .overlay(Circle().stroke(Color.planoraControlStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityTitle)
        .help(accessibilityTitle)
    }
}

private struct CalendarDateButton: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let taskTints: [Color]
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.caption.weight(taskTints.isEmpty ? .medium : .bold))
                    .foregroundStyle(isSelected ? Color.white : Color.planoraInk)

                HStack(spacing: 2) {
                    ForEach(Array(taskTints.enumerated()), id: \.offset) { _, tint in
                        Circle()
                            .fill(isSelected ? Color.white.opacity(0.92) : tint)
                            .frame(width: 3, height: 3)
                    }
                }
                .frame(height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 38)
            .background(isSelected ? Color.planoraDeepGreen : Color.clear, in: Circle())
            .overlay {
                if isToday && !isSelected {
                    Circle().stroke(Color.planoraDeepGreen, lineWidth: 1)
                }
            }
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct CalendarTaskRow: View {
    let task: PlanoraTask

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : task.type.symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(task.isCompleted ? Color.planoraGreen : task.type.tint)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)
                    .lineLimit(1)

                Text(task.subject.planoraDisplaySubjectName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            PriorityPill(priority: task.priority)

            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .opacity(task.isCompleted ? 0.62 : 1)
    }
}

private extension String {
    var planoraDisplaySubjectName: String {
        PlanoraFormat.subjectDisplayName(self)
    }
}
