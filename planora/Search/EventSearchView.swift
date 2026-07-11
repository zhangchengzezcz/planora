import SwiftData
import SwiftUI

// MARK: - Search Screen

struct EventSearchView: View {
    @Bindable var store: PlanoraStore
    let isActive: Bool
    let focusRequestID: Int

    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var searchText = ""
    @State private var selectedSubject: String?
    @State private var selectedType: TaskType?
    @State private var deadlineFilter = SearchDeadlineFilter.all
    @State private var completionFilter = SearchCompletionFilter.all
    @State private var selectedPriority: TaskPriority?
    @State private var focusCancellationID = 0
    @FocusState private var isSearchFocused: Bool

    init(store: PlanoraStore, isActive: Bool = true, focusRequestID: Int = 0) {
        self.store = store
        self.isActive = isActive
        self.focusRequestID = focusRequestID
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchableTasks: [PlanoraTask] {
        tasks.sorted(by: sortSearchResults)
    }

    private var subjectOptions: [String] {
        Array(Set(tasks.map(\.subject))).sorted {
            PlanoraFormat.subjectDisplayName($0) < PlanoraFormat.subjectDisplayName($1)
        }
    }

    private var typeOptions: [TaskType] {
        Array(Set(tasks.map(\.type))).sorted { $0.title < $1.title }
    }

    private var hasActiveFilters: Bool {
        selectedSubject != nil
            || selectedType != nil
            || deadlineFilter != .all
            || completionFilter != .all
            || selectedPriority != nil
    }

    private var selectedSubjectTitle: String {
        guard let selectedSubject else { return L("科目", "Subject") }
        return PlanoraFormat.subjectDisplayName(selectedSubject)
    }

    private var filteredTasks: [PlanoraTask] {
        let candidates = searchableTasks.filter(matchesFilters)
        guard !trimmedSearchText.isEmpty else { return candidates }

        // Search uses a score instead of a raw contains check so short queries like
        // "ee" match EE-related tasks without matching "feedback" or "sheet".
        return candidates
            .compactMap { task -> (task: PlanoraTask, score: Int)? in
                guard let score = task.searchScore(for: trimmedSearchText) else { return nil }
                return (task, score)
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                return sortSearchResults(lhs.task, rhs.task)
            }
            .map(\.task)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L("搜索", "Search"))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.planoraInk)

                    Text(L("快速查找任务、事件和重要日期。", "Quickly find tasks, events, and important dates."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                EventSearchField(text: $searchText, isFocused: $isSearchFocused)
                filterBar

                if filteredTasks.isEmpty {
                    EmptyEventSearchCard(
                        isSearching: !trimmedSearchText.isEmpty || hasActiveFilters,
                        hasTasks: !searchableTasks.isEmpty
                    )
                } else {
                    DashboardSection(title: trimmedSearchText.isEmpty && !hasActiveFilters ? L("全部项目", "All Items") : L("搜索结果", "Search Results")) {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredTasks.enumerated()), id: \.element.id) { index, task in
                                NavigationLink {
                                    TaskDetailView(store: store, task: task)
                                } label: {
                                    EventSearchRow(task: task)
                                }
                                .buttonStyle(.plain)

                                if index != filteredTasks.indices.last {
                                    Divider().padding(.leading, 56)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
        .task(id: SearchFocusState(requestID: focusRequestID, cancellationID: focusCancellationID)) {
            guard isActive, focusRequestID > 0 else {
                isSearchFocused = false
                return
            }

            // Wait for the system Search tab transition before requesting focus.
            do {
                try await Task.sleep(nanoseconds: 160_000_000)
            } catch {
                return
            }

            await MainActor.run {
                isSearchFocused = true
            }
        }
        .onChange(of: isActive) { _, isActive in
            if !isActive {
                focusCancellationID += 1
                isSearchFocused = false
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Menu {
                    filterButton(title: L("全部科目", "All Subjects"), isSelected: selectedSubject == nil) {
                        selectedSubject = nil
                    }

                    ForEach(subjectOptions, id: \.self) { subject in
                        filterButton(
                            title: PlanoraFormat.subjectDisplayName(subject),
                            isSelected: selectedSubject == subject
                        ) {
                            selectedSubject = subject
                        }
                    }
                } label: {
                    SearchFilterChip(
                        title: selectedSubjectTitle,
                        systemImage: "book.closed",
                        isActive: selectedSubject != nil
                    )
                }

                Menu {
                    filterButton(title: L("全部类型", "All Types"), isSelected: selectedType == nil) {
                        selectedType = nil
                    }

                    ForEach(typeOptions) { type in
                        filterButton(title: type.title, isSelected: selectedType == type) {
                            selectedType = type
                        }
                    }
                } label: {
                    SearchFilterChip(
                        title: selectedType?.title ?? L("任务类型", "Task Type"),
                        systemImage: "square.grid.2x2",
                        isActive: selectedType != nil
                    )
                }

                Menu {
                    ForEach(SearchDeadlineFilter.allCases) { filter in
                        filterButton(title: filter.title, isSelected: deadlineFilter == filter) {
                            deadlineFilter = filter
                        }
                    }
                } label: {
                    SearchFilterChip(
                        title: deadlineFilter == .all ? L("截止日期", "Deadline") : deadlineFilter.title,
                        systemImage: "calendar",
                        isActive: deadlineFilter != .all
                    )
                }

                Menu {
                    ForEach(SearchCompletionFilter.allCases) { filter in
                        filterButton(title: filter.title, isSelected: completionFilter == filter) {
                            completionFilter = filter
                        }
                    }
                } label: {
                    SearchFilterChip(
                        title: completionFilter == .all ? L("状态", "Status") : completionFilter.title,
                        systemImage: "checkmark.circle",
                        isActive: completionFilter != .all
                    )
                }

                Menu {
                    filterButton(title: L("全部优先级", "Any Priority"), isSelected: selectedPriority == nil) {
                        selectedPriority = nil
                    }

                    ForEach(TaskPriority.allCases) { priority in
                        filterButton(title: priority.title, isSelected: selectedPriority == priority) {
                            selectedPriority = priority
                        }
                    }
                } label: {
                    SearchFilterChip(
                        title: selectedPriority?.title ?? L("优先级", "Priority"),
                        systemImage: "flag",
                        isActive: selectedPriority != nil
                    )
                }

                if hasActiveFilters {
                    Button(action: clearFilters) {
                        Label(L("清除筛选", "Clear Filters"), systemImage: "xmark.circle.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.planoraDeepGreen)
                            .frame(minHeight: 36)
                            .padding(.horizontal, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 1)
        }
    }

    private func filterButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if isSelected {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }

    private func matchesFilters(_ task: PlanoraTask) -> Bool {
        if let selectedSubject, task.subject != selectedSubject {
            return false
        }

        if let selectedType, task.type != selectedType {
            return false
        }

        if let selectedPriority, task.priority != selectedPriority {
            return false
        }

        switch completionFilter {
        case .all:
            break
        case .open where task.isCompleted:
            return false
        case .completed where !task.isCompleted:
            return false
        default:
            break
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        switch deadlineFilter {
        case .all:
            return true
        case .overdue:
            guard task.hasDeadline, let deadline = task.deadline else { return false }
            return deadline < today && !task.isCompleted
        case .today:
            guard task.hasDeadline, let deadline = task.deadline else { return false }
            return calendar.isDate(deadline, inSameDayAs: today)
        case .nextSevenDays:
            guard task.hasDeadline, let deadline = task.deadline,
                  let end = calendar.date(byAdding: .day, value: 7, to: today) else { return false }
            return deadline >= today && deadline < end
        case .noDeadline:
            return !task.hasDeadline || task.deadline == nil
        }
    }

    private func clearFilters() {
        selectedSubject = nil
        selectedType = nil
        deadlineFilter = .all
        completionFilter = .all
        selectedPriority = nil
    }

    private func sortSearchResults(_ lhs: PlanoraTask, _ rhs: PlanoraTask) -> Bool {
        if lhs.isCompleted != rhs.isCompleted {
            return !lhs.isCompleted
        }

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
            return lhs.createdDate > rhs.createdDate
        }

        return lhs.createdDate > rhs.createdDate
    }
}

// MARK: - Search UI

private struct SearchFocusState: Hashable {
    let requestID: Int
    let cancellationID: Int
}

private enum SearchDeadlineFilter: String, CaseIterable, Identifiable {
    case all
    case overdue
    case today
    case nextSevenDays
    case noDeadline

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L("任意截止日期", "Any Deadline")
        case .overdue: L("已逾期", "Overdue")
        case .today: L("今天", "Today")
        case .nextSevenDays: L("未来 7 天", "Next 7 Days")
        case .noDeadline: L("无截止日期", "No deadline")
        }
    }
}

private enum SearchCompletionFilter: String, CaseIterable, Identifiable {
    case all
    case open
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L("全部状态", "Any Status")
        case .open: L("进行中", "Open")
        case .completed: L("已完成", "Completed")
        }
    }
}

private struct SearchFilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.caption2.weight(.bold))
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(isActive ? Color.white : Color.planoraInk)
        .frame(minHeight: 36)
        .padding(.horizontal, 12)
        .background(isActive ? Color.planoraDeepGreen : Color.planoraGlassFill, in: Capsule())
        .overlay(Capsule().stroke(isActive ? Color.clear : Color.planoraControlStroke, lineWidth: 1))
        .contentShape(Capsule())
    }
}

private struct EventSearchField: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding

    var body: some View {
        let shape = Capsule()

        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.planoraDeepGreen)

            TextField(L("搜索任务或事件", "Search tasks or events"), text: $text)
                .font(.headline)
                .foregroundStyle(Color.planoraInk)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused(isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 54)
        .background(Color.planoraGlassFill, in: shape)
        .glassEffect(.regular.tint(Color.planoraGlassTint).interactive(), in: shape)
        .overlay(shape.stroke(Color.planoraGlassStroke, lineWidth: 1))
    }
}

private struct EventSearchRow: View {
    let task: PlanoraTask

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                Image(systemName: task.type.symbol)
                    .font(.headline)
                    .foregroundStyle(task.type.tint)
                    .frame(width: 42, height: 42)
                    .background(task.type.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.headline)
                        .foregroundStyle(Color.planoraInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(task.subject.planoraSearchDisplayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                PriorityPill(priority: task.priority)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                EventSearchStatusTile(label: L("截止日期", "Deadline"), value: task.deadlineText)
                if task.tracksProgress {
                    EventSearchStatusTile(label: task.progressState.label, value: task.progressState.valueText)
                } else {
                    EventSearchStatusTile(label: L("类型", "Type"), value: task.type.title)
                }
            }

            if !task.notes.isEmpty {
                Text(task.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(18)
    }
}

private struct EventSearchStatusTile: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.planoraInk)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct EmptyEventSearchCard: View {
    let isSearching: Bool
    let hasTasks: Bool

    private var title: String {
        if isSearching {
            return L("没有找到匹配内容", "No Matching Items")
        }

        return hasTasks ? L("输入关键词搜索任务", "Search Tasks") : L("还没有任务", "No Tasks Yet")
    }

    private var message: String {
        if isSearching {
            return L("换一个关键词，或检查标题、科目、类型和备注。", "Try another keyword, or check the title, subject, type, and notes.")
        }

        return hasTasks
            ? L("可以按标题、科目、类型、备注或阶段查找。", "You can search by title, subject, type, notes, or stage.")
            : L("创建任务后，这里会显示所有可搜索内容。", "After you create tasks, all searchable items will appear here.")
    }

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.title.weight(.bold))
                    .foregroundStyle(LinearGradient.planoraAccent)

                Text(title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Search Ranking

private extension PlanoraTask {
    var deadlineText: String {
        guard hasDeadline, let deadline else {
            return L("无截止日期", "No deadline")
        }

        return PlanoraFormat.monthDay(deadline)
    }

    func searchScore(for query: String) -> Int? {
        SearchRanker.score(
            query: query,
            fields: [
                SearchField(value: title, weight: 90),
                SearchField(value: type.title, weight: 110),
                SearchField(value: subject.planoraSearchDisplayName, weight: 100),
                SearchField(value: deadlineText, weight: 24),
                SearchField(value: tracksProgress ? progressState.valueText : L("仅记录", "Record only"), weight: 36),
                SearchField(value: notes, weight: 16)
            ]
        )
    }
}

private struct SearchField {
    let value: String
    let weight: Int
}

private enum SearchRanker {
    static func score(query: String, fields: [SearchField]) -> Int? {
        let normalizedQuery = query.planoraNormalizedSearchString
        let queryTokens = normalizedQuery.planoraSearchTokens

        guard !normalizedQuery.isEmpty, !queryTokens.isEmpty else { return nil }

        var totalScore = 0

        for token in queryTokens {
            let bestTokenScore = fields
                .compactMap { field in
                    score(token: token, normalizedQuery: normalizedQuery, in: field)
                }
                .max()

            guard let bestTokenScore else { return nil }
            totalScore += bestTokenScore
        }

        if queryTokens.count > 1 {
            let phraseBonus = fields
                .filter { $0.value.planoraNormalizedSearchString.contains(normalizedQuery) }
                .map { $0.weight / 2 }
                .max() ?? 0
            totalScore += phraseBonus
        }

        return totalScore
    }

    private static func score(token queryToken: String, normalizedQuery: String, in field: SearchField) -> Int? {
        let normalizedValue = field.value.planoraNormalizedSearchString
        let valueTokens = normalizedValue.planoraSearchTokens

        guard !normalizedValue.isEmpty else { return nil }

        if normalizedValue == normalizedQuery {
            return field.weight + 70
        }

        if valueTokens.contains(queryToken) {
            return field.weight + 48
        }

        // Two-letter academic abbreviations should match token starts only. Broader
        // substring matching starts at three characters to reduce noisy results.
        if queryToken.count >= 2, valueTokens.contains(where: { $0.hasPrefix(queryToken) }) {
            return field.weight + 26
        }

        if queryToken.count >= 3, valueTokens.contains(where: { $0.contains(queryToken) }) {
            return field.weight + 8
        }

        return nil
    }
}

private extension String {
    var planoraSearchDisplayName: String {
        PlanoraFormat.subjectDisplayName(self)
    }

    var planoraNormalizedSearchString: String {
        let foldedString = folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()

        let scalars = foldedString.unicodeScalars.map { scalar in
            CharacterSet.alphanumerics.contains(scalar) ? Character(scalar) : " "
        }

        return String(scalars)
            .split(separator: " ")
            .joined(separator: " ")
    }

    var planoraSearchTokens: [String] {
        planoraNormalizedSearchString
            .split(separator: " ")
            .map(String.init)
    }
}
