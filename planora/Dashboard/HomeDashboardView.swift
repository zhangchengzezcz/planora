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
    @State private var hasRefreshedScheduledWork = false

    // MARK: - View

    var body: some View {
        let snapshot = HomeDashboardSnapshot(tasks: tasks)

        ScrollView(showsIndicators: false) {
            contentStack(snapshot: snapshot)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
        .onAppear {
            refreshScheduledWorkIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                refreshScheduledWork()
                hasRefreshedScheduledWork = true
            }
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

    private func refreshScheduledWorkIfNeeded() {
        guard !hasRefreshedScheduledWork else { return }
        refreshScheduledWork()
        hasRefreshedScheduledWork = true
    }

    private func refreshScheduledWork() {
        var didNormalizeDates = false
        for task in tasks {
            didNormalizeDates = task.normalizeCalendarDates() || didNormalizeDates
        }
        if didNormalizeDates {
            PlanoraTaskPersistence.save(modelContext)
        }
        let didExtendSeries = RecurringTaskEngine.ensureRollingSeries(tasks: tasks, in: modelContext)
        if didExtendSeries {
            PlanoraTaskPersistence.reconcile(fallbackTasks: tasks, in: modelContext)
        } else {
            PlanoraTaskPersistence.reconcile(tasks: tasks)
        }
    }

    private func contentStack(snapshot: HomeDashboardSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HomeHeader(store: store) { curriculum in
                requestCurriculumSwitch(to: curriculum)
            }

            PlanningDestinationStrip(store: store)

            taskOverviewSection(snapshot: snapshot)
            learningProgressSection(snapshot: snapshot)
            calendarPreviewSection(snapshot: snapshot)
        }
        .padding(.top, 18)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func taskOverviewSection(snapshot: HomeDashboardSnapshot) -> some View {
        if let focusTask = snapshot.focusTask {
            TodayFocusCard(store: store, task: focusTask)
            upcomingProgressSection(tasks: snapshot.upcomingProgressTasks)
            upcomingTimelineSection(tasks: snapshot.upcomingTimelineItems)
        } else if snapshot.hasTasks {
            AllTasksCompletedCard()
        } else {
            EmptyTasksCard(action: onCreateRequested)
        }
    }

    @ViewBuilder
    private func upcomingProgressSection(tasks: [PlanoraTask]) -> some View {
        if !tasks.isEmpty {
            DashboardSection(title: L("即将到来的任务", "Upcoming Tasks")) {
                TaskList(store: store, tasks: tasks)
            }
        }
    }

    @ViewBuilder
    private func upcomingTimelineSection(tasks: [PlanoraTask]) -> some View {
        if !tasks.isEmpty {
            DashboardSection(title: L("时间与事件", "Dates and Events")) {
                TaskList(store: store, tasks: tasks)
            }
        }
    }

    @ViewBuilder
    private func learningProgressSection(snapshot: HomeDashboardSnapshot) -> some View {
        if snapshot.hasTasks {
            DashboardSection(title: L("学习进度", "Learning Progress")) {
                VStack(alignment: .leading, spacing: 18) {
                    if !snapshot.subjectProgress.isEmpty {
                        ProgressGroupTitle(L("科目进度", "Subject Progress"))

                        ForEach(snapshot.subjectProgress) { subject in
                            ProgressSubjectRow(title: subject.title, value: subject.value, tint: subject.tint)
                        }

                        Divider()
                    }

                    ProgressGroupTitle(L("任务完成", "Task Completion"))
                    TaskCompletionRow(snapshot: snapshot.taskCompletion)

                    Divider()

                    LearningInsightsGrid(
                        completedThisWeek: snapshot.completedThisWeek,
                        mostActiveSubject: snapshot.mostActiveSubject,
                        upcomingWorkload: "\(snapshot.workloadLevel.title) · \(LF("task_count_short_format", snapshot.upcomingSevenDayCount))",
                        workloadTint: snapshot.workloadLevel.tint,
                        overdueCount: snapshot.overdueCount
                    )
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private func calendarPreviewSection(snapshot: HomeDashboardSnapshot) -> some View {
        if !snapshot.deadlineTasks.isEmpty {
            DashboardSection(title: L("日历预览", "Calendar Preview")) {
                CalendarPreview(
                    store: store,
                    tasks: snapshot.deadlineTasks,
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
        PlanoraTaskOperations.switchCurriculum(
            to: curriculum,
            tasks: tasks,
            modelContext: modelContext,
            store: store
        )
        pendingCurriculum = nil
    }
}

private struct HomeDashboardSnapshot {
    let hasTasks: Bool
    let focusTask: PlanoraTask?
    let upcomingProgressTasks: [PlanoraTask]
    let upcomingTimelineItems: [PlanoraTask]
    let taskCompletion: TaskCompletionSnapshot
    let completedThisWeek: Int
    let mostActiveSubject: String
    let upcomingSevenDayCount: Int
    let overdueCount: Int
    let workloadLevel: LearningWorkloadLevel
    let subjectProgress: [SubjectProgressSnapshot]
    let deadlineTasks: [PlanoraTask]

    init(tasks: [PlanoraTask], now: Date = Date(), calendar: Calendar = .current) {
        hasTasks = !tasks.isEmpty

        let sortedTasks = tasks.planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInDashboardOrder(lhs, rhs)
        }
        var focusTask: PlanoraTask?
        var upcomingProgressTasks: [PlanoraTask] = []
        var upcomingTimelineItems: [PlanoraTask] = []
        var deadlineTasks: [PlanoraTask] = []

        for task in sortedTasks {
            if task.hasDeadline, task.deadline != nil {
                deadlineTasks.append(task)
            }

            guard !task.isCompleted else { continue }
            if focusTask == nil {
                focusTask = task
            }
            if task.tracksProgress, upcomingProgressTasks.count < 4 {
                upcomingProgressTasks.append(task)
            } else if !task.tracksProgress, upcomingTimelineItems.count < 4 {
                upcomingTimelineItems.append(task)
            }
        }

        self.focusTask = focusTask
        self.upcomingProgressTasks = upcomingProgressTasks
        self.upcomingTimelineItems = upcomingTimelineItems
        self.deadlineTasks = deadlineTasks

        let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now)
            ?? DateInterval(start: calendar.startOfDay(for: now), duration: 7 * 86_400)
        let today = calendar.startOfDay(for: now)
        let sevenDayEnd = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        var weeklyTotal = 0
        var completedThisWeek = 0
        var subjectCounts: [String: Int] = [:]
        var upcomingSevenDayCount = 0
        var overdueCount = 0
        var progressBySubject: [String: SubjectProgressAccumulator] = [:]

        for task in tasks {
            let schedulingDate = task.deadline ?? task.createdDate
            let completionFallsInWeek = task.completedDate.map(currentWeek.contains) == true
            let schedulingFallsInWeek = currentWeek.contains(schedulingDate)
            if schedulingFallsInWeek || completionFallsInWeek {
                weeklyTotal += 1
            }

            let completedInWeek: Bool
            if task.isCompleted, let completedDate = task.completedDate {
                completedInWeek = currentWeek.contains(completedDate)
            } else {
                completedInWeek = task.isCompleted && schedulingFallsInWeek
            }
            if completedInWeek {
                completedThisWeek += 1
            }

            if !task.isCompleted || completionFallsInWeek {
                subjectCounts[task.subject, default: 0] += 1
            }

            if !task.isCompleted, task.hasDeadline, let deadline = task.deadline {
                if deadline < today {
                    overdueCount += 1
                } else if deadline < sevenDayEnd {
                    upcomingSevenDayCount += 1
                }
            }

            if task.tracksProgress {
                let subject = PlanoraFormat.subjectDisplayName(task.subject)
                var accumulator = progressBySubject[subject] ?? SubjectProgressAccumulator(
                    total: 0,
                    count: 0,
                    tint: task.type.tint
                )
                accumulator.total += task.progressFraction
                accumulator.count += 1
                progressBySubject[subject] = accumulator
            }
        }

        taskCompletion = TaskCompletionSnapshot(
            title: L("本周", "This Week"),
            completed: completedThisWeek,
            total: weeklyTotal,
            tint: .planoraGreen
        )
        self.completedThisWeek = completedThisWeek
        self.upcomingSevenDayCount = upcomingSevenDayCount
        self.overdueCount = overdueCount

        mostActiveSubject = subjectCounts.max { lhs, rhs in
            if lhs.value != rhs.value { return lhs.value < rhs.value }
            return PlanoraFormat.subjectDisplayName(lhs.key) > PlanoraFormat.subjectDisplayName(rhs.key)
        }
        .map { PlanoraFormat.subjectDisplayName($0.key) }
        ?? L("暂无", "None Yet")

        switch upcomingSevenDayCount {
        case 0...2: workloadLevel = .low
        case 3...5: workloadLevel = .moderate
        default: workloadLevel = .high
        }

        subjectProgress = progressBySubject.map { subject, value in
            SubjectProgressSnapshot(
                title: subject,
                value: value.total / Double(value.count),
                tint: value.tint
            )
        }
        .sorted { $0.title < $1.title }
    }
}

private struct SubjectProgressAccumulator {
    var total: Double
    var count: Int
    let tint: Color
}

// MARK: - Header

private struct HomeHeader: View {
    let store: PlanoraStore
    let onCurriculumSelected: (Curriculum) -> Void

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(LF("home_hello_user_format", store.userName))
                    .font(.largeTitle.weight(.bold))
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

    var body: some View {
        let snapshot = CalendarPreviewSnapshot(
            tasks: tasks,
            monthDate: monthDate,
            selectedDate: selectedDate
        )

        VStack(alignment: .leading, spacing: 16) {
            calendarHeader(snapshot: snapshot)

            LazyVGrid(columns: columns, spacing: 8) {
                weekdayHeaders
                calendarCells(snapshot: snapshot)
            }

            Divider()

            selectedDaySection(snapshot: snapshot)
        }
        .onAppear(perform: selectInitialDate)
        .onChange(of: monthDate) { _, _ in
            selectInitialDate()
        }
    }

    private func calendarHeader(snapshot: CalendarPreviewSnapshot) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(PlanoraFormat.monthYear(monthDate))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(LF("calendar_item_count_format", snapshot.monthTaskCount))
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
    private func calendarCells(snapshot: CalendarPreviewSnapshot) -> some View {
        ForEach(Array(snapshot.calendarDays.enumerated()), id: \.offset) { _, date in
            if let date {
                CalendarDateButton(
                    date: date,
                    isSelected: selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } == true,
                    isToday: Calendar.current.isDateInToday(date),
                    taskTints: snapshot.taskTints(on: date)
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
    private func selectedDaySection(snapshot: CalendarPreviewSnapshot) -> some View {
        if let selectedDate {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(PlanoraFormat.monthDay(selectedDate))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Spacer()

                    Text(LF("task_count_short_format", snapshot.selectedTasks.count))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if snapshot.selectedTasks.isEmpty {
                    Text(L("这一天没有截止任务。", "No deadlines on this day."))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(snapshot.selectedTasks.enumerated()), id: \.element.id) { index, task in
                            NavigationLink {
                                TaskDetailView(store: store, task: task)
                            } label: {
                                CalendarTaskRow(task: task)
                            }
                            .buttonStyle(.plain)

                            if index != snapshot.selectedTasks.indices.last {
                                Divider().padding(.leading, 44)
                            }
                        }
                    }
                }
            }
        }
    }

    private func selectInitialDate() {
        let calendar = Calendar.current
        if calendar.isDate(Date(), equalTo: monthDate, toGranularity: .month) {
            selectedDate = Date()
            return
        }

        selectedDate = CalendarPreviewSnapshot(
            tasks: tasks,
            monthDate: monthDate,
            selectedDate: nil,
            calendar: calendar
        )
            .firstDeadline
            ?? calendar.dateInterval(of: .month, for: monthDate)?.start
    }

    private func changeMonth(by value: Int) {
        monthDate = Calendar.current.date(byAdding: .month, value: value, to: monthDate) ?? monthDate
    }
}

private struct CalendarPreviewSnapshot {
    let monthTaskCount: Int
    let selectedTasks: [PlanoraTask]
    let calendarDays: [Date?]
    let firstDeadline: Date?
    private let taskTintsByDay: [Date: [Color]]
    private let calendar: Calendar

    init(
        tasks: [PlanoraTask],
        monthDate: Date,
        selectedDate: Date?,
        calendar: Calendar = .current
    ) {
        self.calendar = calendar
        guard let monthInterval = calendar.dateInterval(of: .month, for: monthDate),
              let dayRange = calendar.range(of: .day, in: .month, for: monthDate) else {
            monthTaskCount = 0
            selectedTasks = []
            calendarDays = []
            firstDeadline = nil
            taskTintsByDay = [:]
            return
        }

        var tasksByDay: [Date: [PlanoraTask]] = [:]
        var taskTintsByDay: [Date: [Color]] = [:]
        var monthTaskCount = 0
        var firstDeadline: Date?

        for task in tasks {
            guard let deadline = task.deadline, monthInterval.contains(deadline) else { continue }
            monthTaskCount += 1
            firstDeadline = min(firstDeadline ?? deadline, deadline)
            let day = calendar.startOfDay(for: deadline)
            tasksByDay[day, default: []].append(task)
            if taskTintsByDay[day, default: []].count < 3 {
                taskTintsByDay[day, default: []].append(task.type.tint)
            }
        }

        let selectedDay = selectedDate.map { calendar.startOfDay(for: $0) }
        selectedTasks = selectedDay.flatMap { tasksByDay[$0] }?.planoraSorted { lhs, rhs in
            PlanoraTaskOrdering.areInCalendarDayOrder(lhs, rhs)
        } ?? []
        self.monthTaskCount = monthTaskCount
        self.firstDeadline = firstDeadline
        self.taskTintsByDay = taskTintsByDay

        let firstWeekday = calendar.component(.weekday, from: monthInterval.start)
        let leadingEmptyCount = (firstWeekday + 5) % 7
        let emptyDays = Array<Date?>(repeating: nil, count: leadingEmptyCount)
        let dates = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
        calendarDays = emptyDays + dates.map(Optional.some)
    }

    func taskTints(on date: Date) -> [Color] {
        taskTintsByDay[calendar.startOfDay(for: date)] ?? []
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
