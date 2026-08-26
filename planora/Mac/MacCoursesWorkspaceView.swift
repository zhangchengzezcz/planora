import SwiftData
import SwiftUI

#if os(macOS)
struct MacCoursesWorkspaceView: View {
    let store: PlanoraStore
    @Query(sort: \PlanoraCourse.displayName) private var courses: [PlanoraCourse]
    @Query(sort: \PlanoraUnit.title) private var units: [PlanoraUnit]
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @State private var isShowingManageBac = false

    private var activeCourses: [PlanoraCourse] {
        courses.filter { !$0.isArchived }
    }

    var body: some View {
        NavigationStack {
            List(activeCourses) { course in
                NavigationLink {
                    MacCourseDetail(course: course, units: units, tasks: tasks)
                } label: {
                    MacCourseRow(course: course)
                }
            }
            .overlay {
                if activeCourses.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Imported Courses"),
                        systemImage: "book.closed",
                        description: Text(String(localized: "Connect ManageBac and sync to read your student courses."))
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isShowingManageBac = true
                } label: {
                    Label(String(localized: "ManageBac"), systemImage: "arrow.triangle.2.circlepath")
                }
                .help(String(localized: "Connect or sync ManageBac"))
            }
        }
        .sheet(isPresented: $isShowingManageBac) {
            NavigationStack {
                ManageBacSettingsView(store: store)
            }
            .frame(minWidth: 680, idealWidth: 760, minHeight: 600, idealHeight: 720)
        }
    }
}

private struct MacCourseRow: View {
    let course: PlanoraCourse

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "book")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(course.displayName)
                    .font(.headline)
                if !course.teachers.isEmpty {
                    Text(course.teachers.map(\.name).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if course.originalName != course.displayName {
                    Text(course.originalName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 5)
    }
}

private struct MacCourseDetail: View {
    let course: PlanoraCourse
    let units: [PlanoraUnit]
    let tasks: [PlanoraTask]

    private var courseUnits: [PlanoraUnit] {
        units.filter { $0.courseID == course.id && !$0.isArchived }
    }

    private var courseTasks: [PlanoraTask] {
        tasks.filter { $0.courseID == course.id && !$0.isArchived }
    }

    var body: some View {
        let taskCountByUnitID = Dictionary(grouping: courseTasks.compactMap { task -> (UUID, PlanoraTask)? in
            guard let unitID = task.unitID else { return nil }
            return (unitID, task)
        }, by: \.0).mapValues(\.count)

        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(course.displayName).font(.largeTitle.bold())
                    Text(course.originalName).foregroundStyle(.secondary)
                }

                HStack(spacing: 28) {
                    LabeledContent(String(localized: "Tasks"), value: "\(courseTasks.count)")
                    LabeledContent(String(localized: "Units"), value: "\(courseUnits.count)")
                    if let level = course.level {
                        LabeledContent(String(localized: "Level"), value: level.title)
                    }
                }
                .frame(maxWidth: 560)

                if !course.teacherNames.isEmpty {
                    GroupBox(String(localized: "Teachers")) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(course.teachers) { teacher in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "person")
                                        .foregroundStyle(.secondary)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(teacher.name)
                                            .font(.body.weight(.medium))
                                        if let email = teacher.email {
                                            Text(email)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .textSelection(.enabled)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                    }
                }

                if !courseUnits.isEmpty {
                    GroupBox(String(localized: "Units")) {
                        VStack(spacing: 0) {
                            ForEach(Array(courseUnits.enumerated()), id: \.element.id) { index, unit in
                                HStack {
                                    Text(unit.title)
                                    Spacer()
                                    Text("\(taskCountByUnitID[unit.id, default: 0])")
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                }
                                .padding(.vertical, 7)
                                if index < courseUnits.count - 1 { Divider() }
                            }
                        }
                        .padding(6)
                    }
                }

                GroupBox(String(localized: "Tasks")) {
                    if courseTasks.isEmpty {
                        Text(String(localized: "No tasks"))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(courseTasks.prefix(10).enumerated()), id: \.element.id) { index, task in
                                MacCompactTaskRow(task: task)
                                if index < min(courseTasks.count, 10) - 1 { Divider() }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(28)
        }
        .navigationTitle(course.displayName)
    }
}
#endif
