import Charts
import SwiftUI

enum GradeDisplayMode: String, CaseIterable, Identifiable {
    case numbers, bars, line

    var id: Self { self }
    var symbol: String {
        switch self {
        case .numbers: "list.number"
        case .bars: "chart.bar.fill"
        case .line: "chart.xyaxis.line"
        }
    }
    var title: String {
        switch self {
        case .numbers: String(localized: "Numbers")
        case .bars: String(localized: "Bar Chart")
        case .line: String(localized: "Line Chart")
        }
    }
}

struct GradeEntry: Identifiable {
    let id: UUID
    let title: String
    let subject: String
    let date: Date
    let result: String
    let fraction: Double?
    var tint: Color { Self.tint(for: subject) }

    static func tint(for subject: String) -> Color {
        let name = subject.lowercased()
        if name.contains("physics") || name.contains("物理") { return Color(red: 0.05, green: 0.58, blue: 0.56) }
        if name.contains("chem") || name.contains("化学") { return Color(red: 0.86, green: 0.37, blue: 0.20) }
        if name.contains("math") || name.contains("数学") { return Color(red: 0.23, green: 0.40, blue: 0.87) }
        if name.contains("chinese") || name.contains("语文") { return Color(red: 0.72, green: 0.29, blue: 0.54) }
        if name.contains("english") || name.contains("英语") { return Color(red: 0.36, green: 0.51, blue: 0.16) }
        let palette: [Color] = [.cyan, .indigo, .mint, .pink, .orange, .teal]
        let index = subject.utf8.reduce(UInt64(14695981039346656037)) {
            ($0 ^ UInt64($1)) &* 1099511628211
        }
        return palette[Int(index % UInt64(palette.count))]
    }

    init?(task: PlanoraTask) {
        guard !task.isDeleted, !task.isArchived, task.isManageBacTask,
              let result = task.manageBacAssessmentSummary else { return nil }
        id = task.id
        title = task.title
        subject = task.subject
        date = task.deadline ?? task.createdDate
        self.result = result
        if let earned = task.remoteScoreEarned, let possible = task.remoteScorePossible, possible > 0 {
            fraction = min(max(earned / possible, 0), 1)
        } else {
            fraction = nil
        }
    }

    init(assessment: PlanoraAssessment) {
        id = assessment.id
        title = assessment.title
        subject = assessment.subject
        date = assessment.date
        result = "\(assessment.earnedScore.formatted()) / \(assessment.maximumScore.formatted())"
        fraction = assessment.percentage
    }
}

struct GradeModePicker: View {
    @Binding var selection: GradeDisplayMode
    let modes: [GradeDisplayMode]

    var body: some View {
        Picker(String(localized: "Grade Display"), selection: $selection) {
            ForEach(modes) { mode in
                Image(systemName: mode.symbol)
                    .accessibilityLabel(mode.title)
                    .help(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .frame(width: CGFloat(modes.count) * 58)
        .accessibilityLabel(String(localized: "Grade Display"))
    }
}

struct GradeVisualization: View {
    let entries: [GradeEntry]
    let mode: GradeDisplayMode

    private var plotted: [GradeEntry] { entries.filter { $0.fraction != nil } }

    var body: some View {
        if plotted.isEmpty {
            Text(String(localized: "No comparable numeric scores yet"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        } else if mode == .bars {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(plotted) { entry in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(entry.result).font(.headline).monospacedDigit()
                            Spacer(minLength: 0)
                            GeometryReader { proxy in
                                VStack {
                                    Spacer(minLength: 0)
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(entry.tint.gradient)
                                        .frame(height: max(3, proxy.size.height * (entry.fraction ?? 0)))
                                }
                            }
                            .frame(height: 108)
                            Text(entry.title).font(.caption.weight(.semibold)).lineLimit(2)
                            Text(PlanoraFormat.subjectDisplayName(entry.subject))
                                .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Text(entry.date, format: .dateTime.month().day())
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .frame(width: 128, height: 196, alignment: .leading)
                        .padding(12)
                        .background(entry.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 2)
            }
        } else {
            Chart(plotted.sorted { $0.date < $1.date }) { entry in
                LineMark(x: .value("Date", entry.date), y: .value("Score", (entry.fraction ?? 0) * 100),
                         series: .value("Subject", entry.subject))
                    .foregroundStyle(entry.tint)
                PointMark(x: .value("Date", entry.date), y: .value("Score", (entry.fraction ?? 0) * 100))
                    .foregroundStyle(entry.tint)
                    .annotation(position: .top) { Text(entry.result).font(.caption2).monospacedDigit() }
            }
            .chartYScale(domain: 0...100)
            .frame(height: 220)
            .accessibilityLabel(String(localized: "Grade Trend"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Array(Set(plotted.map(\.subject))).sorted(), id: \.self) { subject in
                        Label(PlanoraFormat.subjectDisplayName(subject), systemImage: "circle.fill")
                            .foregroundStyle(GradeEntry.tint(for: subject))
                            .font(.caption)
                    }
                }
            }
        }
    }
}
