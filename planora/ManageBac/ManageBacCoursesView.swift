import SwiftData
import SwiftUI

struct ManageBacCoursesView: View {
    let store: PlanoraStore

    @Query(sort: \PlanoraCourse.displayName) private var courses: [PlanoraCourse]

    private var activeCourses: [PlanoraCourse] {
        courses.filter { $0.externalSource == .manageBac && !$0.isArchived }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "ManageBac Courses"))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.planoraInk)
                    Text(String(localized: "Courses, teachers, units, and imported tasks stay connected in one local workspace."))
                        .font(.callout.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if activeCourses.isEmpty {
                    GlassPanel {
                        ContentUnavailableView(
                            String(localized: "No Imported Courses"),
                            systemImage: "book.closed",
                            description: Text(String(localized: "Connect ManageBac and sync to read your student courses."))
                        )
                    }
                } else {
                    ForEach(activeCourses) { course in
                        NavigationLink {
                            ManageBacCourseDetailView(store: store, course: course)
                        } label: {
                            ManageBacCourseRow(course: course)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }
}

private struct ManageBacCourseRow: View {
    let course: PlanoraCourse

    var body: some View {
        GlassPanel(interactive: true) {
            HStack(spacing: 14) {
                Image(systemName: "book.pages.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(course.curriculum.tint)
                    .frame(width: 48, height: 48)
                    .background(course.curriculum.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 7) {
                        Text(course.displayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.planoraInk)
                        if let level = course.level {
                            Text(level.rawValue.uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(course.curriculum.tint)
                        }
                    }
                    .lineLimit(1)

                    Text(course.teacherNames.isEmpty ? String(localized: "Teacher not listed") : course.teacherNames.joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if course.needsRemoteReview {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.planoraAmber)
                        .accessibilityLabel(String(localized: "Needs Review"))
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ManageBacCourseDetailView: View {
    let store: PlanoraStore
    let course: PlanoraCourse

    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @Query(sort: \PlanoraUnit.title) private var units: [PlanoraUnit]

    private var courseTasks: [PlanoraTask] {
        tasks.filter { $0.courseID == course.id && !$0.isArchived }
    }

    private var courseUnits: [PlanoraUnit] {
        units.filter { $0.courseID == course.id && !$0.isArchived }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header

                HStack(spacing: 12) {
                    NavigationLink {
                        ManageBacCourseTasksView(store: store, course: course)
                    } label: {
                        CourseDestinationTile(
                            title: String(localized: "Tasks"),
                            value: "\(courseTasks.count)",
                            symbol: "checklist",
                            tint: .planoraBlue
                        )
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ManageBacUnitsView(course: course)
                    } label: {
                        CourseDestinationTile(
                            title: String(localized: "Units"),
                            value: "\(courseUnits.count)",
                            symbol: "square.stack.3d.up.fill",
                            tint: .planoraGreen
                        )
                    }
                    .buttonStyle(.plain)
                }

                if !course.teacherNames.isEmpty {
                    DashboardSection(title: String(localized: "Teachers")) {
                        VStack(spacing: 0) {
                            ForEach(Array(course.teacherNames.enumerated()), id: \.offset) { index, name in
                                HStack(spacing: 12) {
                                    Image(systemName: "person.crop.circle.fill")
                                        .foregroundStyle(course.curriculum.tint)
                                    Text(name)
                                        .font(.body.weight(.medium))
                                        .foregroundStyle(Color.planoraInk)
                                    Spacer()
                                }
                                .padding(16)
                                if index < course.teacherNames.count - 1 { Divider().padding(.leading, 48) }
                            }
                        }
                    }
                }

                DashboardSection(title: String(localized: "ManageBac Source")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(course.originalName)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.planoraInk)
                        Text(String(localized: "This course is read from ManageBac and stored only in Planora on this device."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
            }
            .padding(.top, 18)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .planoraDetailNavigationBar()
        .background(PlanoraBackground())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(course.displayName)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(Color.planoraInk)
            HStack(spacing: 8) {
                Text(course.curriculum.badge)
                if let level = course.level { Text(level.rawValue.uppercased()) }
                Text(String(localized: "ManageBac"))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(course.curriculum.tint)
        }
    }
}

private struct CourseDestinationTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        GlassPanel(padding: 16, interactive: true) {
            VStack(alignment: .leading, spacing: 18) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(tint)
                HStack(alignment: .lastTextBaseline) {
                    Text(title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.planoraInk)
                    Spacer()
                    Text(value)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(tint)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ManageBacCourseTasksView: View {
    let store: PlanoraStore
    let course: PlanoraCourse
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]

    private var filteredTasks: [PlanoraTask] {
        tasks.filter { $0.courseID == course.id && !$0.isArchived }
    }

    var body: some View {
        List(filteredTasks) { task in
            NavigationLink {
                TaskDetailView(store: store, task: task)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title).font(.headline)
                    Text(task.type.title).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(String(localized: "Tasks"))
    }
}

private struct ManageBacUnitsView: View {
    let course: PlanoraCourse
    @Query(sort: \PlanoraUnit.title) private var units: [PlanoraUnit]
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]

    private var filteredUnits: [PlanoraUnit] {
        units.filter { $0.courseID == course.id && !$0.isArchived }
    }

    var body: some View {
        List(filteredUnits) { unit in
            VStack(alignment: .leading, spacing: 8) {
                Text(unit.title)
                    .font(.headline)
                HStack {
                    Text(progressSource(for: unit))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(PlanoraFormat.percent(progress(for: unit)))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(course.curriculum.tint)
                }
                ProgressView(value: progress(for: unit))
                    .tint(course.curriculum.tint)
            }
            .padding(.vertical, 4)
        }
        .overlay {
            if filteredUnits.isEmpty {
                ContentUnavailableView(
                    String(localized: "No Units Found"),
                    systemImage: "square.stack.3d.up",
                    description: Text(String(localized: "Sync again after your school publishes units in ManageBac."))
                )
            }
        }
        .navigationTitle(String(localized: "Units"))
    }

    private func progress(for unit: PlanoraUnit) -> Double {
        if let official = unit.officialProgress { return official }
        let related = tasks.filter { $0.unitID == unit.id && !$0.isArchived }
        guard !related.isEmpty else { return 0 }
        return Double(related.filter(\.isCompleted).count) / Double(related.count)
    }

    private func progressSource(for unit: PlanoraUnit) -> String {
        unit.officialProgress == nil ? String(localized: "Planora task progress") : String(localized: "ManageBac progress")
    }
}
