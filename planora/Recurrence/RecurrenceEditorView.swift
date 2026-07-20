import SwiftUI

struct RecurrenceDraftEditorView: View {
    @Binding var rule: TaskRecurrenceRule?
    let startDate: Date
    let tint: Color

    @State private var isEnabled: Bool
    @State private var draft: TaskRecurrenceRule

    init(rule: Binding<TaskRecurrenceRule?>, startDate: Date, tint: Color) {
        _rule = rule
        self.startDate = startDate
        self.tint = tint
        _isEnabled = State(initialValue: rule.wrappedValue != nil)
        _draft = State(initialValue: rule.wrappedValue ?? TaskRecurrenceRule())
    }

    var body: some View {
        Form {
            Section {
                Toggle(String(localized: "Repeat Task"), isOn: $isEnabled)
                    .tint(tint)
            }

            if isEnabled {
                Section(String(localized: "Frequency")) {
                    Picker(String(localized: "Frequency"), selection: $draft.frequency) {
                        ForEach(RecurrenceFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }

                    if draft.frequency == .custom {
                        Stepper(value: $draft.interval, in: 1...30) {
                            Text(PlanoraLocalization.format(String(localized: "repeat_every_format"), draft.interval, draft.customUnit.title))
                        }
                        Picker(String(localized: "Interval Unit"), selection: $draft.customUnit) {
                            ForEach(RecurrenceUnit.allCases) { unit in
                                Text(unit.title).tag(unit)
                            }
                        }
                    }

                    if usesWeekdays {
                        weekdayPicker
                    }
                }

                Section(String(localized: "Ends")) {
                    Picker(String(localized: "End Option"), selection: endMode) {
                        Text(String(localized: "Never")).tag(RecurrenceEndMode.never)
                        Text(String(localized: "On Date")).tag(RecurrenceEndMode.onDate)
                        Text(String(localized: "After Count")).tag(RecurrenceEndMode.afterCount)
                    }

                    switch draft.end {
                    case .never:
                        EmptyView()
                    case .onDate(let date):
                        DatePicker(
                            String(localized: "End Date"),
                            selection: Binding(
                                get: { date },
                                set: { draft.end = .onDate(max($0, startDate)) }
                            ),
                            in: startDate...,
                            displayedComponents: .date
                        )
                    case .afterCount(let count):
                        Stepper(value: Binding(
                            get: { count },
                            set: { draft.end = .afterCount($0) }
                        ), in: 2...500) {
                            Text(PlanoraLocalization.format(String(localized: "repeat_count_format"), count))
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PlanoraBackground())
        .navigationTitle(String(localized: "Repeat"))
        .planoraDetailNavigationBar()
        .onChange(of: isEnabled) { _, enabled in
            rule = enabled ? normalizedDraft : nil
        }
        .onChange(of: draft) { _, _ in
            if isEnabled { rule = normalizedDraft }
        }
    }

    private var usesWeekdays: Bool {
        draft.frequency == .weekly
            || draft.frequency == .biweekly
            || (draft.frequency == .custom && draft.customUnit == .week)
    }

    private var weekdayPicker: some View {
        HStack(spacing: 7) {
            ForEach(1...7, id: \.self) { weekday in
                Button {
                    if draft.weekdays.contains(weekday) {
                        draft.weekdays.remove(weekday)
                    } else {
                        draft.weekdays.insert(weekday)
                    }
                } label: {
                    Text(weekdaySymbol(weekday))
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .foregroundStyle(draft.weekdays.contains(weekday) ? Color.white : Color.planoraInk)
                        .background(draft.weekdays.contains(weekday) ? tint : Color.secondary.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var normalizedDraft: TaskRecurrenceRule {
        var value = draft
        value.interval = max(value.interval, 1)
        if usesWeekdays, value.weekdays.isEmpty {
            value.weekdays = [Calendar.current.component(.weekday, from: startDate)]
        }
        return value
    }

    private var endMode: Binding<RecurrenceEndMode> {
        Binding(
            get: {
                switch draft.end {
                case .never: .never
                case .onDate: .onDate
                case .afterCount: .afterCount
                }
            },
            set: { mode in
                switch mode {
                case .never:
                    draft.end = .never
                case .onDate:
                    draft.end = .onDate(Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate)
                case .afterCount:
                    draft.end = .afterCount(10)
                }
            }
        )
    }

    private func weekdaySymbol(_ weekday: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = PlanoraLocalization.preferredLocale
        let symbols = formatter.veryShortWeekdaySymbols ?? ["S", "M", "T", "W", "T", "F", "S"]
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "?"
    }
}

private enum RecurrenceEndMode: Hashable {
    case never
    case onDate
    case afterCount
}
