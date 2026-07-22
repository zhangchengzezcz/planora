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
        guard let selectedSubject else { return String(localized: "Subject") }
        return PlanoraFormat.subjectDisplayName(selectedSubject)
    }

    private var filteredTasks: [PlanoraTask] {
        PlanoraTaskSearchEngine.results(
            in: tasks,
            query: trimmedSearchText,
            matching: matchesFilters
        )
    }

    var body: some View {
        let results = filteredTasks
        let lastResultID = results.last?.id

        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "Search"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)

                    Text(String(localized: "Quickly find tasks, events, and important dates."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 18)

                EventSearchField(text: $searchText, isFocused: $isSearchFocused)
                filterBar

                if results.isEmpty {
                    EmptyEventSearchCard(
                        isSearching: !trimmedSearchText.isEmpty || hasActiveFilters,
                        hasTasks: !tasks.isEmpty
                    )
                } else {
                    DashboardSection(title: trimmedSearchText.isEmpty && !hasActiveFilters ? String(localized: "All Items") : String(localized: "Search Results")) {
                        LazyVStack(spacing: 0) {
                            ForEach(results) { task in
                                NavigationLink {
                                    TaskDetailView(store: store, task: task)
                                } label: {
                                    EventSearchRow(task: task)
                                }
                                .buttonStyle(.plain)

                                if task.id != lastResultID {
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
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            Menu {
                filterButton(title: String(localized: "All Subjects"), isSelected: selectedSubject == nil) {
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
                filterButton(title: String(localized: "All Types"), isSelected: selectedType == nil) {
                    selectedType = nil
                }

                ForEach(typeOptions) { type in
                    filterButton(title: type.title, isSelected: selectedType == type) {
                        selectedType = type
                    }
                }
            } label: {
                SearchFilterChip(
                    title: selectedType?.title ?? String(localized: "Task Type"),
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
                    title: deadlineFilter == .all ? String(localized: "Deadline") : deadlineFilter.title,
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
                    title: completionFilter == .all ? String(localized: "Status") : completionFilter.title,
                    systemImage: "checkmark.circle",
                    isActive: completionFilter != .all
                )
            }

            Menu {
                filterButton(title: String(localized: "Any Priority"), isSelected: selectedPriority == nil) {
                    selectedPriority = nil
                }

                ForEach(TaskPriority.allCases) { priority in
                    filterButton(title: priority.title, isSelected: selectedPriority == priority) {
                        selectedPriority = priority
                    }
                }
            } label: {
                SearchFilterChip(
                    title: selectedPriority?.title ?? String(localized: "Priority"),
                    systemImage: "flag",
                    isActive: selectedPriority != nil
                )
            }

            if hasActiveFilters {
                Button(action: clearFilters) {
                    Label(String(localized: "Clear Filters"), systemImage: "xmark.circle.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.planoraDeepGreen)
                        .frame(minHeight: 36)
                        .padding(.horizontal, 10)
                }
                .buttonStyle(.plain)
            }
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
        case .all: String(localized: "Any Deadline")
        case .overdue: String(localized: "Overdue")
        case .today: String(localized: "Today")
        case .nextSevenDays: String(localized: "Next 7 Days")
        case .noDeadline: String(localized: "No deadline")
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
        case .all: String(localized: "Any Status")
        case .open: String(localized: "Open")
        case .completed: String(localized: "Completed")
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
        .frame(maxWidth: .infinity, minHeight: 36)
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
        HStack(spacing: 10) {
            let searchShape = Capsule()

            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.planoraInk)

                TextField(String(localized: "Search tasks or events"), text: $text)
                    .font(.title3)
                    .foregroundStyle(Color.planoraInk)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .focused(isFocused)
                    .onSubmit {
                        isFocused.wrappedValue = false
                    }

                Image(systemName: "mic.fill")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(Color.planoraGlassFill, in: searchShape)
            .glassEffect(.regular.tint(Color.planoraGlassTint).interactive(), in: searchShape)
            .overlay(searchShape.stroke(Color.planoraGlassStroke, lineWidth: 1))

            if isFocused.wrappedValue {
                Button {
                    isFocused.wrappedValue = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.title2.weight(.medium))
                        .foregroundStyle(Color.planoraInk)
                        .frame(width: 58, height: 58)
                        .background(Color.planoraGlassFill, in: Circle())
                        .glassEffect(.regular.tint(Color.planoraGlassTint).interactive(), in: Circle())
                        .overlay(Circle().stroke(Color.planoraGlassStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Dismiss Keyboard"))
                .transition(.scale(scale: 0.88).combined(with: .opacity))
            }
        }
        .animation(.smooth(duration: 0.2), value: isFocused.wrappedValue)
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
                EventSearchStatusTile(label: String(localized: "Deadline"), value: task.deadlineText)
                if task.tracksProgress {
                    EventSearchStatusTile(label: task.progressState.label, value: task.progressState.valueText)
                } else {
                    EventSearchStatusTile(label: String(localized: "Type"), value: task.type.title)
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
            return String(localized: "No Matching Items")
        }

        return hasTasks ? String(localized: "Search Tasks") : String(localized: "No Tasks Yet")
    }

    private var message: String {
        if isSearching {
            return String(localized: "Try another keyword, or check the title, subject, type, and notes.")
        }

        return hasTasks
            ? String(localized: "You can search by title, subject, type, notes, or stage.")
            : String(localized: "After you create tasks, all searchable items will appear here.")
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

enum PlanoraTaskSearchEngine {
    static func results(
        in tasks: [PlanoraTask],
        query: String,
        matching matchesFilters: (PlanoraTask) -> Bool = { _ in true }
    ) -> [PlanoraTask] {
        let candidates = tasks.filter(matchesFilters)
        guard !query.isEmpty else {
            return candidates.planoraSorted { lhs, rhs in
                PlanoraTaskOrdering.areInSearchOrder(lhs, rhs)
            }
        }

        // Search uses a score instead of a raw contains check so short queries like
        // "ee" match EE-related tasks without matching "feedback" or "sheet".
        return candidates
            .compactMap { task -> (task: PlanoraTask, score: Int, sortKey: PlanoraTaskSortKey)? in
                guard let score = task.searchScore(for: query) else { return nil }
                return (task, score, PlanoraTaskSortKey(task: task))
            }
            .sorted { lhs, rhs in
                if lhs.score != rhs.score {
                    return lhs.score > rhs.score
                }

                return PlanoraTaskOrdering.areInSearchOrder(lhs.sortKey, rhs.sortKey)
            }
            .map(\.task)
    }
}

extension PlanoraTask {
    var deadlineText: String {
        guard hasDeadline, let deadline else {
            return String(localized: "No deadline")
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
                SearchField(value: tracksProgress ? progressState.valueText : String(localized: "Record only"), weight: 36),
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
