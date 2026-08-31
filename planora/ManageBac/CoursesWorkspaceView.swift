import SwiftData
import SwiftUI

struct CoursesWorkspaceView: View {
    let store: PlanoraStore

    @Query(sort: \PlanoraCourse.displayName) private var courses: [PlanoraCourse]
    @Query(sort: \PlanoraTask.createdDate, order: .reverse) private var tasks: [PlanoraTask]
    @Query(sort: \PlanoraMessage.publishedDate, order: .reverse) private var messages: [PlanoraMessage]
    @Query(sort: \PlanoraScheduleEvent.startDate) private var schedule: [PlanoraScheduleEvent]
    @State private var connection = ManageBacConnectionStorage.load()
    @State private var section: CoursesWorkspaceSection = .courses

    private var subjects: [String] {
        var seen = Set<String>()
        return (store.selectedSubjectTitles + store.selectedExtraLearningTitles).filter {
            seen.insert($0).inserted
        }
    }

    private var importedCourses: [PlanoraCourse] {
        courses.filter { $0.externalSource == .manageBac && !$0.isArchived }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                Picker(String(localized: "Courses"), selection: $section) {
                    ForEach(CoursesWorkspaceSection.allCases) { item in Text(item.title).tag(item) }
                }
                .pickerStyle(.segmented)

                switch section {
                case .courses:
                    manageBacSection
                    if !subjects.isEmpty { subjectSection }
                    if !importedCourses.isEmpty { importedCourseSection }
                case .timetable:
                    ManageBacTimetableList(events: schedule)
                case .messages:
                    ManageBacMessageList(messages: messages)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .contentMargins(.horizontal, PlanoraTheme.pageHorizontalPadding, for: .scrollContent)
        .safeAreaBar(edge: .top, spacing: 0) {
            header
        }
        .scrollEdgeEffectStyle(.automatic, for: .top)
        .planoraHiddenNavigationBar()
        .background(PlanoraBackground())
        .onAppear {
            connection = ManageBacConnectionStorage.load()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Courses"))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(Color.planoraInk)

                Text(String(localized: "Courses, teachers, units, and imported tasks stay connected in one local workspace."))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)
            ProfileAvatarLink(store: store)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, PlanoraTheme.pageHorizontalPadding)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var manageBacSection: some View {
        DashboardSection(title: String(localized: "ManageBac")) {
            NavigationLink {
                ManageBacSettingsView(store: store)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: connection == nil ? "link.badge.plus" : "checkmark.circle.fill")
                        .font(.headline)
                        .foregroundStyle(connection == nil ? Color.planoraBlue : Color.planoraGreen)
                        .frame(width: 42, height: 42)
                        .background(
                            (connection == nil ? Color.planoraBlue : Color.planoraGreen).opacity(0.11),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(connection == nil ? String(localized: "Connect Account") : String(localized: "Connected"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.planoraInk)
                        Text(connection?.schoolHost ?? String(localized: "Import courses and tasks from the official ManageBac website."))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private var subjectSection: some View {
        DashboardSection(title: String(localized: "My Subjects")) {
            VStack(spacing: 0) {
                ForEach(Array(subjects.enumerated()), id: \.offset) { index, subject in
                    NavigationLink {
                        SubjectDetailView(store: store, subject: subject)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "book.closed.fill")
                                .font(.headline)
                                .foregroundStyle(store.curriculum.tint)
                                .frame(width: 42, height: 42)
                                .background(store.curriculum.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                            Text(PlanoraFormat.subjectDisplayName(subject))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.planoraInk)

                            Spacer(minLength: 8)

                            Text(PlanoraLocalization.format(
                                String(localized: "task_count_short_format"),
                                tasks.filter { $0.subject == subject && !$0.isArchived && !$0.isDeleted }.count
                            ))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)

                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < subjects.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
        }
    }

    private var importedCourseSection: some View {
        DashboardSection(title: String(localized: "ManageBac Courses")) {
            VStack(spacing: 0) {
                ForEach(Array(importedCourses.enumerated()), id: \.element.id) { index, course in
                    NavigationLink {
                        ManageBacCourseDetailView(store: store, course: course)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "books.vertical.fill")
                                .font(.headline)
                                .foregroundStyle(course.curriculum.tint)
                                .frame(width: 42, height: 42)
                                .background(course.curriculum.tint.opacity(0.11), in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(course.displayName)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color.planoraInk)
                                    .lineLimit(1)

                                Text(course.teachers.isEmpty ? String(localized: "Teacher not listed") : course.teachers.map(\.name).joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer(minLength: 8)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < importedCourses.count - 1 {
                        Divider().padding(.leading, 70)
                    }
                }
            }
        }
    }
}
