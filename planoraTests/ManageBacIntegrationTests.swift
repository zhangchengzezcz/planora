import SwiftData
import WebKit
import XCTest
import SwiftUI
#if os(iOS)
import UIKit
#endif
@testable import planora

@MainActor
final class ManageBacIntegrationTests: XCTestCase {
#if os(iOS)
    func testImportCompletionLayoutOnNarrowPhone() async throws {
        let session = ManageBacWebSession()
        session.phase = .completed(ManageBacImportSummary(
            courseCount: 12, unitCount: 24, importedCount: 18, updatedCount: 3,
            messageCount: 8, scheduleCount: 30
        ))
        session.completedStepCount = 9
        session.courses = [ManageBacCourseRecord(
            remoteIdentifier: "123", name: "全球视野 Global Perspectives PDP2",
            teacherNames: [], detailURL: nil, programmeText: nil
        )]
        let store = PlanoraStore(storage: .preview, loadSavedProfile: false)
        let container = try makeContainer()
        let content = ManageBacConnectionFlowView(
            store: store, flow: .connect, session: session,
            onComplete: { _ in }, onCancel: {}
        ).modelContainer(container)
        let controller = UIHostingController(rootView: content)
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        try await Task.sleep(for: .milliseconds(300))
        controller.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(bounds: controller.view.bounds).image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "ManageBac-iPhone-completed"
        attachment.lifetime = .keepAlways
        add(attachment)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("managebac-iphone-completed.png")
        try image.pngData()?.write(to: url)
        print("IMPORT_SCREENSHOT=\(url.path)")
        XCTAssertEqual(session.phase, .completed(ManageBacImportSummary(
            courseCount: 12, unitCount: 24, importedCount: 18, updatedCount: 3,
            messageCount: 8, scheduleCount: 30
        )))
    }
#endif
    func testConnectionCanRestartAfterTeardown() {
        let session = ManageBacWebSession()
        session.teardown()
        XCTAssertNil(session.webView.navigationDelegate)
        session.startInteractiveConnection()
        XCTAssertTrue(session.webView.navigationDelegate === session)
        XCTAssertTrue(session.webView.uiDelegate === session)
        XCTAssertEqual(session.phase, .authenticating)
        session.cancel()
        XCTAssertEqual(session.phase, .failed(.cancelled))
        session.teardown()
    }

    func testRepeatedMobileCourseLinksKeepTeacherMapping() async throws {
        let webView = try await loadedWebView(html: #"""
        <html><body><main><section>
          <div><a href="/student/classes/123">Math PDP2</a></div>
          <div><a href="/student/classes/123">Math PDP2</a></div>
          <a href="javascript:void(0)">Teacher One</a>
          <span>Units (2) Tasks (3)</span>
        </section><a href="https://other.example/student/classes/999">Unrelated</a>
        </main></body></html>
        """#, url: "https://school.managebac.cn/student/classes/my")
        let result = try await webView.callAsyncJavaScript(
            ManageBacWebSession.courseScript, arguments: [:], in: nil, contentWorld: .page
        )
        let json = try XCTUnwrap(result as? String)
        let payload = try JSONDecoder().decode(CourseListFixturePayload.self, from: Data(json.utf8))
        XCTAssertEqual(payload.courses.count, 1)
        XCTAssertEqual(payload.courses.first?.teacherNames, ["Teacher One"])
    }

    func testCoursePaginationFailureDoesNotReturnPartialSuccess() async throws {
        let webView = try await loadedWebView(html: #"""
        <html><body><main>
        <a href="/student/classes/123">Math PDP2</a>
        <a href="/student/classes/my?page=2">2</a>
        <script>window.fetch = async () => { throw new Error('Offline'); };</script>
        </main></body></html>
        """#, url: "https://school.managebac.cn/student/classes/my")
        do {
            _ = try await webView.callAsyncJavaScript(
                ManageBacWebSession.courseScript, arguments: [:], in: nil, contentWorld: .page
            )
            XCTFail("Partial course lists must not be imported as a successful sync")
        } catch {
            XCTAssertEqual((error as NSError).domain, WKError.errorDomain)
        }
    }

    func testCourseScanRejectsLoginAndIgnoresSidebarCourses() async throws {
        let webView = try await loadedWebView(html: #"""
        <html><body><aside><a href="/student/classes/999">Old Physics</a></aside>
        <main><h1>My Classes</h1><nav><a href="/student/classes/888">Old Maths</a></nav>
        <a href="/student/classes/123">Current Maths</a></main></body></html>
        """#, url: "https://school.managebac.cn/student/classes/my")
        let result = try await webView.callAsyncJavaScript(
            ManageBacWebSession.courseScript, arguments: [:], in: nil, contentWorld: .page
        )
        let json = try XCTUnwrap(result as? String)
        let payload = try JSONDecoder().decode(CourseListFixturePayload.self, from: Data(json.utf8))
        XCTAssertEqual(payload.courses.map(\.remoteIdentifier), ["123"])

        _ = try await webView.evaluateJavaScript("document.body.innerHTML = '<input type=\"password\">';")
        do {
            _ = try await webView.callAsyncJavaScript(
                ManageBacWebSession.courseScript, arguments: [:], in: nil, contentWorld: .page
            )
            XCTFail("A login form must not be treated as an empty course list")
        } catch {
            XCTAssertEqual((error as NSError).domain, WKError.errorDomain)
        }
    }

    func testCurrentManageBacClassCardsReadCourseAndTeachers() async throws {
        let html = #"""
        <!doctype html><html><body><main>
          <section class="class-card">
            <a href="/student/classes/11501444">HS Math PDP2 (Grade 10)</a>
            <a href="javascript:void(0);">Dr. Kwadwo Bonsu</a>
            <a href="javascript:void(0)">Craig Blouin</a>
            <button>Units (21)</button><button>Tasks (4)</button><button>Updates (10)</button>
          </section>
        </main></body></html>
        """#
        let webView = try await loadedWebView(
            html: html,
            url: "https://school.managebac.cn/student/classes/my"
        )

        let result = try await webView.callAsyncJavaScript(
            ManageBacWebSession.courseScript,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        let json = try XCTUnwrap(result as? String)
        let payload = try JSONDecoder().decode(CourseListFixturePayload.self, from: Data(json.utf8))

        XCTAssertEqual(payload.courses.count, 1)
        XCTAssertEqual(payload.courses[0].remoteIdentifier, "11501444")
        XCTAssertEqual(payload.courses[0].name, "HS Math PDP2 (Grade 10)")
        XCTAssertEqual(payload.courses[0].teacherNames, ["Dr. Kwadwo Bonsu", "Craig Blouin"])
    }

    func testCurrentManageBacTaskRouteAndPastStatusAreRecognized() async throws {
        let html = #"""
        <!doctype html><html><body><main>
          <article class="task-card">
            <a href="/student/classes/11501444/core_tasks/27538517">Homework 03</a>
            <span>Sep 8, 1:20 PM</span>
            <a href="/student/classes/11501444">HS Math PDP2 (Grade 10)</a>
            <span>Summative</span><span>Classwork</span>
          </article>
        </main></body></html>
        """#
        let webView = try await loadedWebView(
            html: html,
            url: "https://school.managebac.cn/student/tasks_and_deadlines?view=past"
        )

        let result = try await webView.callAsyncJavaScript(
            ManageBacWebSession.taskScript,
            arguments: ["sourceView": "past"],
            in: nil,
            contentWorld: .page
        )
        let json = try XCTUnwrap(result as? String)
        let payload = try JSONDecoder().decode(ManageBacScanPayload.self, from: Data(json.utf8))

        XCTAssertTrue(payload.pageRecognized)
        XCTAssertEqual(payload.records.count, 1)
        XCTAssertEqual(payload.records[0].remoteIdentifier, "11501444:27538517")
        XCTAssertEqual(payload.records[0].courseIdentifier, "11501444")
        XCTAssertEqual(payload.records[0].subject, "HS Math PDP2 (Grade 10)")
        XCTAssertEqual(payload.records[0].remoteStatus, .past)
        XCTAssertNotNil(payload.records[0].deadline)
    }

    func testCurrentNotificationRowsAreReadFromDedicatedPage() async throws {
        let html = #"""
        <!doctype html><html><body><main>
          <section><h4>New For You</h4>
            <article class="notification-item unread">
              <a href="/student/notifications/245152680"></a>
              <p>New Task: Homework 03: Dr. Kwadwo Bonsu has just added a new Task Homework 03 in HS Math PDP2 (Grade 10). When: September 8, 2026 at 1:20 PM</p>
              <small>HS Math PDP2 (Grade 10) · Dr. Kwadwo Bonsu · Sep 4</small>
            </article>
          </section>
        </main></body></html>
        """#
        let webView = try await loadedWebView(
            html: html,
            url: "https://school.managebac.cn/student/notifications"
        )
        let result = try await webView.callAsyncJavaScript(
            ManageBacWebSession.workspaceScript,
            arguments: ["courseRecords": [[
                "remoteIdentifier": "11501444",
                "name": "HS Math PDP2 (Grade 10)",
                "teacherNames": ["Dr. Kwadwo Bonsu"]
            ]]],
            in: nil,
            contentWorld: .page
        )
        let json = try XCTUnwrap(result as? String)
        let payload = try JSONDecoder().decode(WorkspaceFixturePayload.self, from: Data(json.utf8))

        XCTAssertEqual(payload.messages.count, 1)
        XCTAssertEqual(payload.messages[0].remoteIdentifier, "245152680")
        XCTAssertEqual(payload.messages[0].courseIdentifier, "11501444")
        XCTAssertEqual(payload.messages[0].senderName, "Dr. Kwadwo Bonsu")
        XCTAssertEqual(payload.messages[0].title, "New Task: Homework 03")
        XCTAssertTrue(payload.messages[0].isUnread)
        XCTAssertTrue(payload.schedule.isEmpty)
    }

    func testCurrentWeeklyTimetableTableIsRead() async throws {
        let html = #"""
        <!doctype html><html><body><main>
          <input aria-label="Select Date" value="Aug 31, 2026 - Sep 6, 2026">
          <table><thead><tr><th>Period</th><th>Aug 31, Mon</th><th>Sep 1, Tue</th></tr></thead>
          <tbody><tr><th>1</th>
            <td>7:30 AM - 8:10 AM History Grade 10 阶梯教室201</td>
            <td>7:30 AM - 8:10 AM 1 GP PDP2 Grade 10 Marce Steyn 536</td>
          </tr></tbody></table>
        </main></body></html>
        """#
        let webView = try await loadedWebView(
            html: html,
            url: "https://school.managebac.cn/student/timetables"
        )
        let result = try await webView.callAsyncJavaScript(
            ManageBacWebSession.workspaceScript,
            arguments: ["courseRecords": [
                ["remoteIdentifier": "history", "name": "HS History (Grade 10)", "teacherNames": []],
                ["remoteIdentifier": "gp", "name": "HS GP PDP2 (Grade 10)", "teacherNames": ["Marce Steyn"]]
            ]],
            in: nil,
            contentWorld: .page
        )
        let json = try XCTUnwrap(result as? String)
        let payload = try JSONDecoder().decode(WorkspaceFixturePayload.self, from: Data(json.utf8))

        XCTAssertEqual(payload.schedule.count, 2)
        XCTAssertEqual(payload.schedule[0].title, "History")
        XCTAssertEqual(payload.schedule[0].location, "阶梯教室201")
        XCTAssertEqual(payload.schedule[1].courseIdentifier, "gp")
        XCTAssertEqual(payload.schedule[1].teacherNames, ["Marce Steyn"])
        XCTAssertEqual(payload.schedule[1].location, "536")
        XCTAssertTrue(payload.messages.isEmpty)
    }

    func testRedesignedUnitGridIsReadWithoutCoursePageNavigation() async throws {
        let detailHTML = #"""
        <!doctype html>
        <html><body>
          <main>
            <div data-testid="programme-name">PDP2</div>
            <a href="/student/classes/physics/units">Units</a>
            <span data-testid="teacher-name">Ms Chen</span>
            <article data-testid="unit-grid-item" data-unit-id="mechanics">
              <a href="/student/classes/physics/unit-planners/mechanics">
                <h3 data-testid="unit-title">Mechanics</h3>
              </a>
              <span data-testid="progress">60%</span>
            </article>
          </main>
        </body></html>
        """#
        let webView = WKWebView(frame: .zero)
        webView.loadHTMLString(
            "<!doctype html><html><body></body></html>",
            baseURL: URL(string: "https://school.managebac.cn/student/classes/all")
        )
        for _ in 0..<50 {
            guard webView.isLoading else { break }
            try await Task.sleep(for: .milliseconds(20))
        }

        let emptyResult = try await webView.callAsyncJavaScript(
            ManageBacWebSession.courseDetailsScript,
            arguments: ["courseRequests": []],
            in: nil,
            contentWorld: .page
        )
        XCTAssertEqual(emptyResult as? String, "[]")

        let result = try await webView.callAsyncJavaScript(
            ManageBacWebSession.courseDetailsScript,
            arguments: [
                "courseRequests": [[
                    "courseIdentifier": "physics",
                    "detailURL": "https://school.managebac.cn/student/classes/physics"
                ]],
                "courseHTMLFixtures": [[
                    "courseIdentifier": "physics",
                    "html": detailHTML
                ]]
            ],
            in: nil,
            contentWorld: .page
        )
        let json = try XCTUnwrap(result as? String)
        let payloads = try JSONDecoder().decode([CourseDetailFixturePayload].self, from: Data(json.utf8))
        let payload = try XCTUnwrap(payloads.first)

        XCTAssertEqual(payload.courseIdentifier, "physics")
        XCTAssertEqual(payload.programmeText, "PDP2")
        XCTAssertEqual(payload.teacherNames, ["Ms Chen"])
        XCTAssertEqual(payload.units.map(\.remoteIdentifier), ["mechanics"])
        XCTAssertEqual(payload.units.first?.title, "Mechanics")
        XCTAssertEqual(try XCTUnwrap(payload.units.first?.officialProgress), 0.6, accuracy: 0.001)
    }

    func testDateParserSupportsISOAndManageBacDisplayDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Shanghai"))

        XCTAssertNotNil(ManageBacDateParser.date(from: "2026-09-10T13:30:00+08:00", calendar: calendar))
        XCTAssertNotNil(ManageBacDateParser.date(from: "Sep 10, 2026 1:30 PM", calendar: calendar))
        XCTAssertNil(ManageBacDateParser.date(from: "Not a date", calendar: calendar))
    }

    func testRepeatedSyncUpdatesRemoteFieldsWithoutDuplicatingOrOverwritingLocalWork() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let firstRecord = record(title: "Physics IA", deadline: "2026-09-10", identifier: "task-42")

        let firstSummary = try ManageBacTaskImporter.importRecords(
            [firstRecord, firstRecord],
            courses: ["Physics HL", "Physics HL"],
            existingTasks: [],
            into: context
        )

        XCTAssertEqual(firstSummary.importedCount, 1)
        XCTAssertEqual(firstSummary.updatedCount, 0)

        let importedTask = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraTask>()).first)
        importedTask.notes = "Keep my local notes"
        importedTask.priority = .high
        importedTask.setCompleted(true)
        try context.save()

        let secondRecord = record(title: "Physics IA Final", deadline: "2026-09-12", identifier: "task-42")
        let secondSummary = try ManageBacTaskImporter.importRecords(
            [secondRecord],
            courses: ["Physics HL"],
            existingTasks: try context.fetch(FetchDescriptor<PlanoraTask>()),
            into: context
        )

        let tasks = try context.fetch(FetchDescriptor<PlanoraTask>())
        XCTAssertEqual(tasks.count, 1)
        XCTAssertEqual(secondSummary.importedCount, 0)
        XCTAssertEqual(secondSummary.updatedCount, 1)
        XCTAssertEqual(tasks[0].title, "Physics IA Final")
        XCTAssertEqual(tasks[0].notes, "Keep my local notes")
        XCTAssertEqual(tasks[0].priority, .high)
        XCTAssertTrue(tasks[0].isCompleted)
        XCTAssertEqual(tasks[0].externalIdentifier, "task-42")
    }

    func testBackupRoundTripPreservesManageBacIdentity() throws {
        let task = PlanoraTask(
            title: "TOK Essay",
            subject: "TOK",
            type: .tok,
            deadline: Date(timeIntervalSince1970: 1_800_000_000),
            hasDeadline: true,
            progressState: .percentage(0.25),
            notes: "Local note"
        )
        task.externalSource = .manageBac
        task.externalIdentifier = "deadline-7"
        task.externalURLString = "https://school.managebac.cn/student/tasks/7"
        task.externalUpdatedAt = Date(timeIntervalSince1970: 1_790_000_000)

        let json = try TaskBackupCodec.json(for: [task])
        let restored = try XCTUnwrap(TaskBackupCodec.tasks(from: json).first)

        XCTAssertEqual(restored.externalSource, .manageBac)
        XCTAssertEqual(restored.externalIdentifier, task.externalIdentifier)
        XCTAssertEqual(restored.externalURLString, task.externalURLString)
        XCTAssertEqual(restored.externalUpdatedAt, task.externalUpdatedAt)
    }

    func testProgrammeDetectionTreatsPDPAsIGCSESuggestion() {
        let courses = [
            ManageBacCourseRecord(
                remoteIdentifier: "math",
                name: "PDP Mathematics",
                teacherNames: [],
                detailURL: nil,
                programmeText: "PDP"
            )
        ]

        let result = ManageBacProgrammeDetector.detect(programmeText: "PDP", courses: courses)

        XCTAssertEqual(result.curriculum, .igcse)
        XCTAssertEqual(result.confidence, .medium)
    }

    func testProgrammeDetectionRecognizesNumberedPDPVariants() {
        for value in ["PDP1 Mathematics", "PDP 2 English", "PDP-2 Chemistry"] {
            let result = ManageBacProgrammeDetector.detect(
                programmeText: value,
                courses: [ManageBacCourseRecord(
                    remoteIdentifier: value,
                    name: value,
                    teacherNames: [],
                    detailURL: nil,
                    programmeText: value
                )]
            )
            XCTAssertEqual(result.curriculum, .igcse, value)
            XCTAssertEqual(result.confidence, .medium, value)
        }
    }

    func testGlobalPerspectivesAliasesNormalizeWithoutReview() {
        for value in ["Global Perspectives", "GP PDP2", "GP PDP2 (Grade 10)", "GPTPD"] {
            let record = ManageBacCourseRecord(
                remoteIdentifier: value,
                name: value,
                teacherNames: [],
                detailURL: nil,
                programmeText: "PDP2"
            )
            let normalized = ManageBacCourseNormalizer.normalize(record, curriculum: .igcse)
            XCTAssertEqual(normalized.canonicalSubject, "Global Perspectives", value)
            XCTAssertEqual(normalized.displayName, "Global Perspectives", value)
            XCTAssertFalse(normalized.requiresReview, value)
        }
    }

    func testStoredManageBacCoursesAreRenormalizedWithoutNetworkAccess() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let course = PlanoraCourse(
            displayName: "GP PDP2 (Grade 10)",
            originalName: "GP PDP2 (Grade 10)",
            curriculum: .igcse,
            teacherNames: [
                "Rehman Naseer naseer@example.com",
                "Teachers Rehman Naseer naseer@example.com"
            ],
            externalSource: .manageBac,
            externalIdentifier: "gp-pdp2"
        )
        let task = PlanoraTask(
            title: "Perspective reflection",
            subject: "GP PDP2 (Grade 10)",
            type: .assignment,
            deadline: nil,
            hasDeadline: false,
            progressState: .percentage(0),
            notes: ""
        )
        task.externalSource = .manageBac
        task.courseID = course.id
        context.insert(course)
        context.insert(task)
        try context.save()

        let changed = try ManageBacTaskImporter.refreshStoredCourseMetadata(in: context)

        XCTAssertEqual(changed, 1)
        XCTAssertEqual(course.displayName, "Global Perspectives")
        XCTAssertEqual(course.canonicalSubject, "Global Perspectives")
        XCTAssertFalse(course.needsRemoteReview)
        XCTAssertEqual(course.teacherNames, ["Rehman Naseer naseer@example.com"])
        XCTAssertEqual(task.subject, "Global Perspectives")
    }

    func testTeacherNameAndEmailArePresentedSeparately() {
        let teacher = ParsedTeacher(rawValue: "Rehman Naseer naseer@example.com")
        XCTAssertEqual(teacher.name, "Rehman Naseer")
        XCTAssertEqual(teacher.email, "naseer@example.com")
    }

    func testSnapshotImportsCourseTeachersUnitsAndRemoteCompletion() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let snapshot = ManageBacSyncSnapshot(
            schoolHost: "school.managebac.cn",
            programmeText: "IB Diploma Programme",
            courses: [
                ManageBacCourseRecord(
                    remoteIdentifier: "physics",
                    name: "Physics HL",
                    teacherNames: ["Ms Chen"],
                    detailURL: "https://school.managebac.cn/student/classes/physics",
                    programmeText: "IB Diploma Programme"
                )
            ],
            units: [
                ManageBacUnitRecord(
                    remoteIdentifier: "mechanics",
                    courseIdentifier: "physics",
                    title: "Mechanics",
                    detailURL: nil,
                    startDateText: "2026-08-01",
                    endDateText: "2026-09-01",
                    officialProgress: 0.5
                )
            ],
            tasks: [
                ManageBacTaskRecord(
                    remoteIdentifier: "task-1",
                    title: "Mechanics Quiz",
                    subject: "Physics HL",
                    deadlineText: "2026-09-01",
                    detailURL: nil,
                    sourceView: "completed",
                    courseIdentifier: "physics",
                    unitIdentifier: "mechanics"
                )
            ]
        )

        let summary = try ManageBacTaskImporter.importSnapshot(
            snapshot,
            currentCurriculum: .ib,
            existingTasks: [],
            into: context
        )

        let course = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraCourse>()).first)
        let unit = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraUnit>()).first)
        let task = try XCTUnwrap(try context.fetch(FetchDescriptor<PlanoraTask>()).first)
        XCTAssertEqual(course.teacherNames, ["Ms Chen"])
        XCTAssertEqual(unit.courseID, course.id)
        XCTAssertEqual(task.courseID, course.id)
        XCTAssertEqual(task.unitID, unit.id)
        XCTAssertTrue(task.isCompleted)
        XCTAssertEqual(summary.completedCount, 1)
    }

    func testMissingRemoteTaskIsRetainedForReview() throws {
        let container = try makeContainer()
        let context = container.mainContext
        let task = PlanoraTask(
            title: "Existing",
            subject: "Physics",
            type: .assignment,
            deadline: nil,
            hasDeadline: false,
            progressState: .percentage(0),
            notes: ""
        )
        task.externalSource = .manageBac
        task.externalIdentifier = "remote-existing"
        context.insert(task)
        try context.save()

        let summary = try ManageBacTaskImporter.importSnapshot(
            ManageBacSyncSnapshot(
                schoolHost: "school.managebac.cn",
                programmeText: nil,
                courses: [],
                units: [],
                tasks: []
            ),
            currentCurriculum: .ib,
            existingTasks: [task],
            into: context
        )

        XCTAssertFalse(task.isArchived)
        XCTAssertTrue(task.needsRemoteReview)
        XCTAssertEqual(summary.reviewCount, 1)
    }

    func testV9BackupPreservesTeachersAndUnitRelationships() throws {
        let course = PlanoraCourse(
            displayName: "Physics HL",
            curriculum: .ib,
            teacherNames: ["Ms Chen"],
            externalSource: .manageBac,
            externalIdentifier: "physics"
        )
        let unit = PlanoraUnit(
            courseID: course.id,
            title: "Mechanics",
            externalSource: .manageBac,
            externalIdentifier: "mechanics"
        )
        let task = PlanoraTask(
            title: "Quiz",
            subject: course.displayName,
            type: .assignment,
            deadline: nil,
            hasDeadline: false,
            progressState: .percentage(0),
            notes: ""
        )
        task.courseID = course.id
        task.unitID = unit.id

        let json = try TaskBackupCodec.json(for: [task], courses: [course], units: [unit])
        let content = try TaskBackupCodec.content(from: json)

        XCTAssertEqual(content.courses.first?.teacherNames, ["Ms Chen"])
        let restoredCourse = try XCTUnwrap(content.courses.first)
        let restoredUnit = try XCTUnwrap(content.units.first)
        let restoredTask = try XCTUnwrap(content.tasks.first)
        XCTAssertEqual(restoredUnit.courseID, restoredCourse.id)
        XCTAssertEqual(restoredTask.unitID, restoredUnit.id)
    }

    func testV9BackupPreservesAcademicPlanning() throws {
        let topic = PlanoraTopic(subject: "Physics HL", title: "Mechanics", mastery: 0.75)
        let assessment = PlanoraAssessment(
            title: "Mock 1",
            subject: "Physics HL",
            earnedScore: 84,
            maximumScore: 100,
            date: Date(timeIntervalSince1970: 1_788_000_000),
            type: .mock
        )
        let task = PlanoraTask(
            title: "Physics Mock",
            subject: "Physics HL",
            type: .exam,
            deadline: Date(timeIntervalSince1970: 1_800_000_000),
            hasDeadline: true,
            progressState: .percentage(0.25),
            notes: ""
        )
        task.topicIDs = [topic.id]
        task.examScope = "Mechanics and waves"
        task.targetScore = 90
        task.pastPaperTarget = 6
        task.pastPapersCompleted = 2

        let json = try TaskBackupCodec.json(for: [task], topics: [topic], assessments: [assessment])
        let content = try TaskBackupCodec.content(from: json)

        XCTAssertEqual(content.tasks.first?.topicIDs, [topic.id])
        XCTAssertEqual(content.tasks.first?.examScope, "Mechanics and waves")
        XCTAssertEqual(content.tasks.first?.targetScore, 90)
        XCTAssertEqual(content.tasks.first?.pastPapersCompleted, 2)
        XCTAssertEqual(content.topics.first?.title, "Mechanics")
        XCTAssertEqual(try XCTUnwrap(content.assessments.first).percentage, 0.84, accuracy: 0.001)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: PlanoraTask.self, PlanoraCourse.self, PlanoraUnit.self, PlanoraTopic.self, PlanoraAssessment.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func loadedWebView(html: String, url: String) async throws -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.loadHTMLString(html, baseURL: try XCTUnwrap(URL(string: url)))
        for _ in 0..<250 {
            if !webView.isLoading, webView.url?.host == URL(string: url)?.host,
               let ready = try? await webView.evaluateJavaScript("document.readyState === 'complete' && document.body !== null"),
               ready as? Bool == true {
                return webView
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("The offline ManageBac fixture did not finish loading")
        throw ManageBacConnectionError.invalidResponse
    }

    private func record(title: String, deadline: String, identifier: String) -> ManageBacTaskRecord {
        ManageBacTaskRecord(
            remoteIdentifier: identifier,
            title: title,
            subject: "Physics HL",
            deadlineText: deadline,
            detailURL: "https://school.managebac.cn/student/tasks/42",
            sourceView: "upcoming"
        )
    }
}

private struct WorkspaceFixturePayload: Decodable {
    var messages: [ManageBacMessageRecord]
    var schedule: [ManageBacScheduleRecord]
}

private struct CourseListFixturePayload: Decodable {
    var courses: [ManageBacCourseRecord]
}

private struct CourseDetailFixturePayload: Decodable {
    var courseIdentifier: String
    var programmeText: String?
    var teacherNames: [String]
    var units: [ManageBacUnitRecord]
}
