import Foundation
import Observation
import WebKit

@MainActor
@Observable
final class ManageBacWebSession: NSObject, WKNavigationDelegate, WKUIDelegate {
    enum Mode {
        case interactive
        case silent
    }

    enum Phase: Equatable {
        case idle
        case authenticating
        case verifying
        case loadingCourses
        case identifyingCurriculum
        case loadingUnits
        case loadingTasks
        case loadingWorkspace
        case comparing
        case importing
        case completed(ManageBacImportSummary)
        case needsLogin
        case failed(ManageBacConnectionError)

        var showsOfficialLogin: Bool { self == .authenticating }
    }

    var phase: Phase = .idle
    var courses: [ManageBacCourseRecord] = []
    var units: [ManageBacUnitRecord] = []
    var records: [ManageBacTaskRecord] = []
    var messages: [ManageBacMessageRecord] = []
    var schedule: [ManageBacScheduleRecord] = []
    var programmeText: String?
    var completedStepCount = 0

    @ObservationIgnored var onSnapshotReady: ((ManageBacSyncSnapshot) throws -> ManageBacImportSummary)?
    @ObservationIgnored private(set) lazy var webView: WKWebView = makeWebView()
    @ObservationIgnored private var mode: Mode = .interactive
    @ObservationIgnored private var schoolHost: String?
    @ObservationIgnored private let taskViews = ["upcoming", "past", "overdue"]
    @ObservationIgnored private var currentTaskViewIndex = 0
    @ObservationIgnored private let workspacePaths = ["/student/notifications", "/student/timetables"]
    @ObservationIgnored private var currentWorkspacePathIndex = 0
    @ObservationIgnored private var isHandlingPage = false
    @ObservationIgnored private var needsAnotherPageCheck = false
    @ObservationIgnored private var pageCheckTask: Task<Void, Never>?
    @ObservationIgnored private var pageCheckIdentifier: UUID?
    @ObservationIgnored private var authenticationProbeTask: Task<Void, Never>?
    @ObservationIgnored private var pageLoadWatchdogTask: Task<Void, Never>?
    @ObservationIgnored private var pageLoadGeneration = 0

    func startInteractiveConnection() {
        resetForScan(mode: .interactive)
        phase = .authenticating
        guard let signInURL = URL(string: "https://signin.managebac.com/") else {
            phase = .failed(.unsupportedAddress)
            return
        }
        load(signInURL)
    }

    func startSilentSync(snapshot: ManageBacConnectionSnapshot) {
        guard let url = URL(string: "https://\(snapshot.schoolHost)/student/home") else {
            phase = .failed(.unsupportedAddress)
            return
        }
        resetForScan(mode: .silent)
        schoolHost = snapshot.schoolHost
        phase = .verifying
        load(url)
    }

    func cancel() {
        pageLoadGeneration += 1
        cancelPageCheck()
        authenticationProbeTask?.cancel()
        pageLoadWatchdogTask?.cancel()
        webView.stopLoading()
        phase = .failed(.cancelled)
    }

    func teardown() {
        pageLoadGeneration += 1
        cancelPageCheck()
        authenticationProbeTask?.cancel()
        authenticationProbeTask = nil
        pageLoadWatchdogTask?.cancel()
        pageLoadWatchdogTask = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
        onSnapshotReady = nil
    }

    func clearWebsiteData() async {
        webView.stopLoading()
        let dataStore = WKWebsiteDataStore.default()
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let storedRecords = await dataStore.dataRecords(ofTypes: types)
        let manageBacRecords = storedRecords.filter {
            $0.displayName.localizedCaseInsensitiveContains("managebac") ||
            $0.displayName.localizedCaseInsensitiveContains("faria")
        }
        await dataStore.removeData(ofTypes: types, for: manageBacRecords)
        ManageBacConnectionStorage.clear()
        phase = .idle
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        pageLoadWatchdogTask?.cancel()
        pageLoadWatchdogTask = nil
        enqueuePageCheck()
        scheduleAuthenticationProbesIfNeeded()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        scheduleAuthenticationProbesIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNavigationFailure(error)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences
    ) async -> (WKNavigationActionPolicy, WKWebpagePreferences) {
        guard let url = navigationAction.request.url,
              url.scheme?.lowercased() == "https" else {
            return (.cancel, preferences)
        }

        // A user-tapped universal link can otherwise hand off to the installed
        // ManageBac app. Re-issuing it as a programmatic WebKit load keeps the
        // official sign-in inside Planora.
        if phase == .authenticating, navigationAction.navigationType == .linkActivated {
            webView.load(navigationAction.request)
            return (.cancel, preferences)
        }

        if phase == .authenticating {
            return (.allow, preferences)
        }

        guard navigationAction.request.httpMethod?.uppercased() == "GET",
              let host = url.host?.lowercased(),
              isManageBacHost(host) else {
            return (.cancel, preferences)
        }
        return (.allow, preferences)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              navigationAction.request.url?.scheme?.lowercased() == "https" else { return nil }
        webView.load(navigationAction.request)
        return nil
    }

    private func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self
        view.uiDelegate = self
        view.allowsBackForwardNavigationGestures = false
        view.allowsLinkPreview = false
        view.isInspectable = false
        return view
    }

    private func resetForScan(mode: Mode) {
        cancelPageCheck()
        webView.stopLoading()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        self.mode = mode
        courses = []
        units = []
        records = []
        messages = []
        schedule = []
        programmeText = nil
        schoolHost = nil
        currentTaskViewIndex = 0
        currentWorkspacePathIndex = 0
        completedStepCount = 0
        isHandlingPage = false
        needsAnotherPageCheck = false
        authenticationProbeTask?.cancel()
        authenticationProbeTask = nil
        pageLoadWatchdogTask?.cancel()
        pageLoadWatchdogTask = nil
        pageLoadGeneration += 1
    }

    private func enqueuePageCheck() {
        needsAnotherPageCheck = true
        guard !isHandlingPage else { return }
        isHandlingPage = true
        let identifier = UUID()
        pageCheckIdentifier = identifier
        pageCheckTask = Task {
            repeat {
                needsAnotherPageCheck = false
                await handleLoadedPage()
                guard !Task.isCancelled, pageCheckIdentifier == identifier else { return }
            } while needsAnotherPageCheck
            isHandlingPage = false
            pageCheckTask = nil
            pageCheckIdentifier = nil
        }
    }

    private func cancelPageCheck() {
        pageCheckTask?.cancel()
        pageCheckTask = nil
        pageCheckIdentifier = nil
        needsAnotherPageCheck = false
        isHandlingPage = false
    }

    private func scheduleAuthenticationProbesIfNeeded() {
        guard phase == .authenticating || phase == .verifying else { return }
        authenticationProbeTask?.cancel()
        authenticationProbeTask = Task { [weak self] in
            for delay in [150, 350, 700, 1_200] {
                do {
                    try await Task.sleep(for: .milliseconds(delay))
                } catch {
                    return
                }
                guard let self, !Task.isCancelled,
                      self.phase == .authenticating || self.phase == .verifying else { return }
                if await self.isAuthenticatedStudentPage() {
                    guard !Task.isCancelled else { return }
                    self.enqueuePageCheck()
                    return
                }
            }
        }
    }

    private func handleLoadedPage() async {
        let generation = pageLoadGeneration
        guard let url = webView.url, let host = url.host?.lowercased() else { return }
        if isSignInPage(url) {
            phase = mode == .silent ? .needsLogin : .authenticating
            return
        }
        guard isManageBacHost(host) else {
            if phase != .authenticating { phase = .failed(.unsupportedAddress) }
            return
        }

        switch phase {
        case .authenticating, .verifying:
            let authenticated = await isAuthenticatedStudentPage()
            guard generation == pageLoadGeneration else { return }
            guard authenticated else {
                phase = mode == .silent ? .needsLogin : .authenticating
                scheduleAuthenticationProbesIfNeeded()
                return
            }
            authenticationProbeTask?.cancel()
            authenticationProbeTask = nil
            schoolHost = host
            completedStepCount = 1
            phase = .loadingCourses
            loadStudentPath("/student/classes/my")

        case .loadingCourses:
            do {
                let payload: CourseScanPayload = try await decodeJavaScript(Self.courseScript)
                guard generation == pageLoadGeneration else { return }
                courses = payload.courses
                programmeText = payload.programmeText
                completedStepCount = 2
                phase = .identifyingCurriculum
                completedStepCount = 3
                phase = .loadingUnits
                await readCourseDetails()
                guard generation == pageLoadGeneration else { return }
                completedStepCount = 4
                currentTaskViewIndex = 0
                phase = .loadingTasks
                loadStudentPath("/student/tasks_and_deadlines?view=\(taskViews[0])")
            } catch {
                guard generation == pageLoadGeneration else { return }
                phase = .failed(.pageStructureChanged)
            }

        case .loadingUnits:
            break

        case .loadingTasks:
            do {
                let view = taskViews[currentTaskViewIndex]
                let payload: ManageBacScanPayload = try await decodeJavaScript(
                    Self.taskScript,
                    arguments: ["sourceView": view]
                )
                guard generation == pageLoadGeneration else { return }
                guard payload.pageRecognized else {
                    phase = .failed(.pageStructureChanged)
                    return
                }
                records.append(contentsOf: payload.records)
                currentTaskViewIndex += 1
                if currentTaskViewIndex < taskViews.count {
                    loadStudentPath("/student/tasks_and_deadlines?view=\(taskViews[currentTaskViewIndex])")
                } else {
                    completedStepCount = 5
                    currentWorkspacePathIndex = 0
                    phase = .loadingWorkspace
                    loadStudentPath(workspacePaths[0])
                }
            } catch {
                guard generation == pageLoadGeneration else { return }
                phase = .failed(.pageStructureChanged)
            }
        case .loadingWorkspace:
            do {
                let payload: WorkspaceScanPayload = try await decodeJavaScript(
                    Self.workspaceScript,
                    arguments: ["courseRecords": encodedCourseArguments]
                )
                guard generation == pageLoadGeneration else { return }
                messages.append(contentsOf: payload.messages)
                schedule.append(contentsOf: payload.schedule)
                currentWorkspacePathIndex += 1
                if currentWorkspacePathIndex < workspacePaths.count {
                    loadStudentPath(workspacePaths[currentWorkspacePathIndex])
                } else {
                    completedStepCount = 6
                    finishImport()
                }
            } catch {
                guard generation == pageLoadGeneration else { return }
                advancePastWorkspacePage()
            }
        default:
            break
        }
    }

    private func readCourseDetails() async {
        let generation = pageLoadGeneration
        let requests = courses.compactMap { course -> [String: String]? in
            guard let detailURL = course.detailURL, !detailURL.isEmpty else { return nil }
            return [
                "courseIdentifier": course.remoteIdentifier,
                "detailURL": detailURL
            ]
        }
        guard !requests.isEmpty else { return }

        do {
            let payloads: [CourseDetailPayload] = try await decodeJavaScript(
                Self.courseDetailsScript,
                arguments: ["courseRequests": requests]
            )
            guard generation == pageLoadGeneration else { return }
            let detailsByCourse = Dictionary(
                payloads.map { ($0.courseIdentifier, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            for index in courses.indices {
                guard let detail = detailsByCourse[courses[index].remoteIdentifier] else { continue }
                courses[index].teacherNames = Array(
                    Set(courses[index].teacherNames + detail.teacherNames)
                ).sorted()
                if courses[index].programmeText == nil {
                    courses[index].programmeText = detail.programmeText
                }
                units.append(contentsOf: detail.units)
            }
        } catch {
            // Teacher and unit metadata is optional. A ManageBac layout update
            // must never block task and deadline synchronization.
        }
    }

    private var encodedCourseArguments: [[String: Any]] {
        courses.map { course in
            [
                "remoteIdentifier": course.remoteIdentifier,
                "name": course.name,
                "teacherNames": course.teacherNames
            ]
        }
    }

    private func advancePastWorkspacePage() {
        // Notifications and timetables are optional school modules. A layout
        // change in one module must not discard the core course/task snapshot.
        currentWorkspacePathIndex += 1
        if currentWorkspacePathIndex < workspacePaths.count {
            loadStudentPath(workspacePaths[currentWorkspacePathIndex])
        } else {
            completedStepCount = 6
            finishImport()
        }
    }

    private func finishImport() {
        guard let schoolHost, let onSnapshotReady else {
            phase = .failed(.invalidResponse)
            return
        }
        do {
            phase = .comparing
            completedStepCount = 7
            phase = .importing
            let snapshot = ManageBacSyncSnapshot(
                schoolHost: schoolHost,
                programmeText: programmeText,
                courses: courses,
                units: units,
                tasks: records,
                messages: messages,
                schedule: schedule
            )
            let summary = try onSnapshotReady(snapshot)
            let detection = ManageBacProgrammeDetector.detect(
                programmeText: programmeText,
                courses: courses
            )
            completedStepCount = 9
            ManageBacConnectionStorage.save(
                ManageBacConnectionSnapshot(
                    schoolHost: schoolHost,
                    lastSyncDate: Date(),
                    courseCount: summary.courseCount,
                    taskCount: records.count,
                    detectedCurriculumRawValue: detection.curriculum?.rawValue,
                    detectionConfidenceRawValue: detection.confidence.rawValue
                )
            )
            phase = .completed(summary)
        } catch {
            phase = .failed(.invalidResponse)
        }
    }

    private func loadStudentPath(_ path: String) {
        guard let schoolHost, let url = URL(string: "https://\(schoolHost)\(path)") else {
            phase = .failed(.unsupportedAddress)
            return
        }
        load(url)
    }

    private func load(_ url: URL) {
        pageLoadWatchdogTask?.cancel()
        pageLoadGeneration += 1
        let generation = pageLoadGeneration
        webView.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
        pageLoadWatchdogTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(20))
            } catch {
                return
            }
            guard let self, self.pageLoadGeneration == generation else { return }
            self.handlePageLoadTimeout()
        }
    }

    private func handlePageLoadTimeout() {
        pageLoadWatchdogTask = nil
        webView.stopLoading()
        switch phase {
        case .loadingWorkspace:
            advancePastWorkspacePage()
        case .loadingTasks:
            currentTaskViewIndex += 1
            if currentTaskViewIndex < taskViews.count {
                loadStudentPath("/student/tasks_and_deadlines?view=\(taskViews[currentTaskViewIndex])")
            } else {
                completedStepCount = 5
                phase = .loadingWorkspace
                currentWorkspacePathIndex = 0
                loadStudentPath(workspacePaths[0])
            }
        default:
            phase = .failed(.invalidResponse)
        }
    }

    private func isAuthenticatedStudentPage() async -> Bool {
        guard let url = webView.url,
              let host = url.host?.lowercased(),
              isManageBacHost(host),
              url.path.hasPrefix("/student"),
              !url.path.localizedCaseInsensitiveContains("login"),
              !url.path.localizedCaseInsensitiveContains("sign_in") else { return false }

        let result = try? await webView.callAsyncJavaScript(
            "return Boolean(document.readyState !== 'loading' && location.pathname.startsWith('/student') && !document.querySelector('input[type=\"password\"]') && (document.querySelector('main') || document.querySelector('a[href*=\"/student/tasks_and_deadlines\"]') || document.querySelector('a[href*=\"/student/classes\"]')));",
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        return result as? Bool == true
    }

    private func decodeJavaScript<T: Decodable>(
        _ script: String,
        arguments: [String: Any] = [:]
    ) async throws -> T {
        let result = try await webView.callAsyncJavaScript(
            script,
            arguments: arguments,
            in: nil,
            contentWorld: .page
        )
        guard let json = result as? String, let data = json.data(using: .utf8) else {
            throw ManageBacConnectionError.invalidResponse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func isSignInPage(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host == "signin.managebac.com" || (!url.path.hasPrefix("/student/") && host.contains("signin"))
    }

    private func isManageBacHost(_ host: String) -> Bool {
        host == "managebac.com" || host.hasSuffix(".managebac.com") || host.hasSuffix(".managebac.cn")
    }

    private func handleNavigationFailure(_ error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
        phase = .failed(.invalidResponse)
    }

    private struct CourseScanPayload: Codable {
        var programmeText: String?
        var courses: [ManageBacCourseRecord]
    }

    private struct CourseDetailPayload: Codable {
        var courseIdentifier: String
        var programmeText: String?
        var teacherNames: [String]
        var units: [ManageBacUnitRecord]
    }

    private struct WorkspaceScanPayload: Codable {
        var messages: [ManageBacMessageRecord]
        var schedule: [ManageBacScheduleRecord]
    }

    static let courseScript = #"""
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = value => { try { return new URL(value, location.origin).href; } catch (_) { return ''; } };
    const coursePath = /^\/student\/classes\/([^/?#]+)\/?$/;
    const courseMap = new Map();

    const courseContainer = link => {
      let node = link.parentElement;
      for (let depth = 0; node && depth < 8; depth += 1, node = node.parentElement) {
        const text = normalize(node.textContent);
        const links = Array.from(node.querySelectorAll('a[href]')).filter(item => {
          try { return coursePath.test(new URL(item.getAttribute('href'), location.origin).pathname); } catch (_) { return false; }
        });
        const courseIDs = new Set(links.map(item => new URL(item.getAttribute('href'), location.origin).pathname));
        if (courseIDs.size === 1 && /\bUnits?\b/i.test(text) && /\bTasks?\b/i.test(text) && text.length < 2500) return node;
      }
      return link.closest('article,li,tr,[class*=card]') || link.parentElement;
    };

    const readDocument = (doc, pageURL) => {
      if (doc.querySelector('input[type="password"]')) throw new Error('Course session expired');
      const content = doc.querySelector('main') || doc.body;
      for (const link of content.querySelectorAll('a[href]')) {
        if (link.closest('nav,aside,header')) continue;
        const href = link.getAttribute('href') || '';
        const url = (() => { try { return new URL(href, pageURL); } catch (_) { return null; } })();
        const match = url?.pathname.match(coursePath);
        if (!match || url.origin !== location.origin || ['all', 'my'].includes(match[1].toLowerCase())) continue;
        const name = normalize(link.textContent);
        if (!name || /^(classes|browse all classes|my classes)$/i.test(name)) continue;
        const container = courseContainer(link);
        const teacherNames = Array.from(container?.querySelectorAll('a[href^="javascript:void"],[class*=teacher],[data-role=teacher]') || [])
          .map(node => normalize(node.textContent))
          .filter(value => value && !/^(more information|classes?|units?|tasks?|updates?)$/i.test(value));
        const existing = courseMap.get(match[1]);
        courseMap.set(match[1], {
          remoteIdentifier: match[1],
          name: existing?.name?.startsWith('HS ') ? existing.name : name,
          teacherNames: [...new Set([...(existing?.teacherNames || []), ...teacherNames])],
          detailURL: url.href,
          programmeText: null
        });
      }
    };

    readDocument(document, location.href);
    const paginationURLs = [...new Set(Array.from(document.querySelectorAll('a[href*="/student/classes/my?page="]'))
      .map(link => absolute(link.getAttribute('href')))
      .filter(url => url && new URL(url).origin === location.origin))];
    if (paginationURLs.length > 10) throw new Error('Course pagination limit exceeded');
    const pages = await Promise.allSettled(paginationURLs.map(async url => {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 6000);
      try {
        const response = await fetch(url, { method: 'GET', credentials: 'same-origin', signal: controller.signal, headers: { 'Accept': 'text/html' } });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return { html: await response.text(), url: response.url || url };
      } finally {
        clearTimeout(timeout);
      }
    }));
    for (const page of pages) {
      if (page.status !== 'fulfilled') throw new Error('Course pagination failed');
      const doc = new DOMParser().parseFromString(page.value.html, 'text/html');
      if (doc.querySelector('input[type="password"]') || !new URL(page.value.url).pathname.startsWith('/student/classes')) throw new Error('Course session expired');
      readDocument(doc, page.value.url);
    }
    const main = document.querySelector('main') || document.body;
    if (!courseMap.size && !/my classes|no classes|我的课程|我的班级|暂无课程/i.test(normalize(main?.textContent))) {
      throw new Error('Unrecognized course page');
    }
    const programmeText = normalize(main?.querySelector('[class*=programme],[class*=program],[class*=year-group],[data-testid*=programme],nav[aria-label*=breadcrumb]')?.textContent)
      || normalize(Array.from(courseMap.values()).map(course => course.name).join(' '))
      || null;
    return JSON.stringify({ programmeText, courses: Array.from(courseMap.values()) });
    """#

    static let courseDetailsScript = #"""
    const requests = Array.isArray(courseRequests) ? courseRequests : [];
    const fixtures = typeof courseHTMLFixtures !== 'undefined' && Array.isArray(courseHTMLFixtures)
      ? courseHTMLFixtures
      : [];
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = (value, base) => { try { return new URL(value, base || location.origin).href; } catch (_) { return ''; } };
    const unitPath = /\/(?:units?|unit[-_]?plans?|unit-planners?)\/([^/?#]+)/i;
    const collectionPath = /\/(?:units?|tasks[-_]?and[-_]?units|unit[-_]?plans?|unit-planners?)\/?$/i;
    const ignoredIDs = new Set(['all', 'active', 'archived', 'current', 'grid', 'index', 'my']);

    const readPage = (html, pageURL, courseID) => {
      const doc = new DOMParser().parseFromString(html, 'text/html');
      const teacherSelectors = [
        '[class*=teacher]', '[data-role=teacher]', '[data-testid*=teacher]',
        '[aria-label*=teacher]', 'a[href*="/users/"]', 'a[href*="/teachers/"]'
      ].join(',');
      const teacherNames = Array.from(doc.querySelectorAll(teacherSelectors))
        .map(node => normalize(node.textContent))
        .filter(value => value && value.length < 100);
      const units = [];
      const seen = new Set();
      const addUnit = (container, link, explicitID) => {
        const href = link?.getAttribute('href') || '';
        const detailURL = absolute(href, pageURL);
        const path = (() => { try { return new URL(detailURL).pathname; } catch (_) { return ''; } })();
        const match = path.match(unitPath);
        const remoteIdentifier = normalize(explicitID || match?.[1]);
        if (!remoteIdentifier || ignoredIDs.has(remoteIdentifier.toLowerCase()) || seen.has(remoteIdentifier)) return;
        const title = normalize(
          container?.querySelector('[data-testid*=title],h1,h2,h3,h4,h5,[class*=title],[class*=name]')?.textContent ||
          link?.textContent
        );
        if (!title || /^(units?|tasks\s*&\s*units|view all)$/i.test(title)) return;
        seen.add(remoteIdentifier);
        const times = Array.from(container?.querySelectorAll('time') || []);
        const progressText = normalize(container?.querySelector('[class*=progress],[data-testid*=progress],[aria-label*=progress]')?.textContent);
        const progressMatch = progressText.match(/(\d+(?:\.\d+)?)\s*%/);
        const unitTeachers = Array.from(container?.querySelectorAll(teacherSelectors) || [])
          .map(node => normalize(node.textContent)).filter(Boolean);
        units.push({
          remoteIdentifier,
          courseIdentifier: courseID,
          title,
          detailURL: detailURL || null,
          startDateText: times[0]?.getAttribute('datetime') || null,
          endDateText: times[1]?.getAttribute('datetime') || null,
          officialProgress: progressMatch ? Number(progressMatch[1]) / 100 : null,
          teacherNames: [...new Set(unitTeachers)]
        });
      };

      for (const link of doc.querySelectorAll('a[href]')) {
        const detailURL = absolute(link.getAttribute('href'), pageURL);
        const path = (() => { try { return new URL(detailURL).pathname; } catch (_) { return ''; } })();
        if (!unitPath.test(path)) continue;
        const container = link.closest('[data-unit-id],[data-testid*=unit],article,li,tr,[class*=unit],[class*=card]') || link.parentElement;
        addUnit(container, link, container?.dataset?.unitId);
      }
      for (const container of doc.querySelectorAll('[data-unit-id],[data-testid*=unit-card],[data-testid*=unit-grid-item]')) {
        addUnit(container, container.querySelector('a[href]'), container.dataset.unitId);
      }

      const collectionURLs = Array.from(doc.querySelectorAll('a[href]'))
        .map(link => absolute(link.getAttribute('href'), pageURL))
        .filter(value => {
          try { return collectionPath.test(new URL(value).pathname); } catch (_) { return false; }
        });
      const programmeText = normalize(doc.querySelector('[class*=programme],[class*=program],[class*=year-group],[data-testid*=programme],nav[aria-label*=breadcrumb]')?.textContent) || null;
      return {
        programmeText,
        teacherNames: [...new Set(teacherNames)],
        units,
        collectionURLs: [...new Set(collectionURLs)]
      };
    };

    const fetchHTML = async url => {
      const controller = new AbortController();
      const timeout = setTimeout(() => controller.abort(), 8000);
      try {
        const response = await fetch(url, {
          method: 'GET',
          credentials: 'same-origin',
          redirect: 'follow',
          signal: controller.signal,
          headers: { 'Accept': 'text/html,application/xhtml+xml' }
        });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        return { html: await response.text(), url: response.url || url };
      } finally {
        clearTimeout(timeout);
      }
    };

    const scanCourse = async request => {
      const courseIdentifier = normalize(request.courseIdentifier);
      const empty = { courseIdentifier, programmeText: null, teacherNames: [], units: [] };
      try {
        const fixture = fixtures.find(item => item.courseIdentifier === courseIdentifier);
        const overview = fixture
          ? { html: fixture.html, url: request.detailURL }
          : await fetchHTML(request.detailURL);
        const first = readPage(overview.html, overview.url, courseIdentifier);
        const extraURLs = fixture ? [] : first.collectionURLs.filter(url => url !== overview.url).slice(0, 2);
        const extraResults = await Promise.allSettled(extraURLs.map(fetchHTML));
        const pages = [first];
        for (const result of extraResults) {
          if (result.status === 'fulfilled') {
            pages.push(readPage(result.value.html, result.value.url, courseIdentifier));
          }
        }
        const teacherNames = [...new Set(pages.flatMap(page => page.teacherNames))];
        const unitMap = new Map();
        for (const unit of pages.flatMap(page => page.units)) {
          unitMap.set(`${unit.courseIdentifier}|${unit.remoteIdentifier}`, unit);
        }
        return {
          courseIdentifier,
          programmeText: pages.map(page => page.programmeText).find(Boolean) || null,
          teacherNames,
          units: [...unitMap.values()]
        };
      } catch (_) {
        return empty;
      }
    };

    const results = await Promise.all(requests.map(scanCourse));
    return JSON.stringify(results);
    """#

    static let taskScript = #"""
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = value => { try { return new URL(value, location.origin).href; } catch (_) { return ''; } };
    const currentSourceView = String(sourceView || '').toLowerCase();
    const taskPath = /\/student\/classes\/([^/?#]+)\/core_tasks\/([^/?#]+)/i;
    const candidates = [];
    const seen = new Set();

    const readableContainer = link => {
      const preferred = link.closest('[data-task-id],[data-deadline-id],article,tr,li,[class*=task-card],[class*=deadline-card]');
      if (preferred) return preferred;
      let node = link.parentElement;
      for (let depth = 0; node && depth < 7; depth += 1, node = node.parentElement) {
        const links = Array.from(node.querySelectorAll('a[href]')).filter(item => taskPath.test(absolute(item.getAttribute('href'))));
        const text = normalize(node.textContent);
        if (links.length === 1 && text.length >= normalize(link.textContent).length + 6 && text.length < 1800) return node;
      }
      return link.parentElement;
    };

    const displayDate = container => {
      const time = container?.querySelector('time');
      const explicit = time?.getAttribute('datetime')
        || container?.querySelector('[data-deadline]')?.getAttribute('data-deadline')
        || container?.querySelector('[data-date]')?.getAttribute('data-date');
      if (explicit) return explicit;
      const text = normalize(container?.textContent);
      const match = text.match(/\b(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+(\d{1,2}:\d{2})\s*(AM|PM)\b/i);
      if (!match) return null;
      const currentYear = new Date().getFullYear();
      const parsed = new Date(`${match[1]} ${match[0].match(/\d{1,2}/)?.[0]}, ${currentYear} ${match[2]} ${match[3]}`);
      return Number.isNaN(parsed.valueOf()) ? match[0] : parsed.toISOString();
    };

    for (const link of document.querySelectorAll('a[href]')) {
      const href = link.getAttribute('href') || '';
      const detailURL = absolute(href);
      const match = (() => { try { return new URL(detailURL).pathname.match(taskPath); } catch (_) { return null; } })();
      if (!match) continue;
      const title = normalize(link.textContent);
      if (!title || /^(tasks?|all tasks)$/i.test(title)) continue;
      const courseIdentifier = match[1];
      const taskIdentifier = match[2];
      const remoteIdentifier = `${courseIdentifier}:${taskIdentifier}`;
      if (seen.has(remoteIdentifier)) continue;
      seen.add(remoteIdentifier);
      const container = readableContainer(link);
      const classLink = Array.from(container?.querySelectorAll('a[href]') || []).find(item => {
        try { return new URL(item.getAttribute('href'), location.origin).pathname === `/student/classes/${courseIdentifier}`; } catch (_) { return false; }
      });
      const unitLink = container?.querySelector('a[href*="/units/"]');
      const unitMatch = (() => { try { return new URL(unitLink?.getAttribute('href'), location.origin).pathname.match(/\/units\/([^/?#]+)/); } catch (_) { return null; } })();
      candidates.push({
        remoteIdentifier,
        title,
        subject: normalize(classLink?.textContent),
        deadlineText: displayDate(container),
        detailURL,
        sourceView: currentSourceView,
        courseIdentifier,
        unitIdentifier: unitMatch?.[1] || null,
        remoteStatus: ['upcoming','past','overdue','completed'].includes(currentSourceView) ? currentSourceView : 'unknown'
      });
    }
    const main = document.querySelector('main') || document.body;
    const text = normalize(main?.innerText).toLowerCase();
    const emptyState = /no\s+(upcoming|past|overdue|tasks?)/.test(text);
    const pageRecognized = Boolean(main && (emptyState || candidates.length > 0 || location.pathname.includes('/student/tasks_and_deadlines')));
    return JSON.stringify({ records: candidates, pageRecognized });
    """#

    static let workspaceScript = #"""
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = value => { try { return new URL(value, location.origin).href; } catch (_) { return ''; } };
    const courses = Array.isArray(courseRecords) ? courseRecords : [];
    const messages = [];
    const schedule = [];
    const path = location.pathname;

    const nearestRow = (link, pattern, maxLength = 3000) => {
      const preferred = link.closest('article,li,tr,[data-testid*=notification],[class*=notification-item],[class*=notification-row]');
      if (preferred) return preferred;
      let node = link.parentElement;
      for (let depth = 0; node && depth < 8; depth += 1, node = node.parentElement) {
        const matchingLinks = Array.from(node.querySelectorAll('a[href]')).filter(item => pattern.test(absolute(item.getAttribute('href'))));
        const text = normalize(node.textContent);
        if (matchingLinks.length === 1 && text.length > 12 && text.length < maxLength) return node;
      }
      return link.parentElement;
    };

    const dateToISO = raw => {
      if (!raw) return null;
      const clean = normalize(raw);
      const withYear = /\b\d{4}\b/.test(clean) ? clean : `${clean}, ${new Date().getFullYear()}`;
      const parsed = new Date(withYear);
      return Number.isNaN(parsed.valueOf()) ? clean : parsed.toISOString();
    };

    if (path.startsWith('/student/notifications')) {
      const notificationPath = /\/student\/notifications\/(\d+)/;
      const links = Array.from(document.querySelectorAll('a[href]')).filter(link => notificationPath.test(absolute(link.getAttribute('href'))));
      if (!links.length && /loading/i.test(document.body.innerText || '')) {
        await new Promise(resolve => {
          const started = Date.now();
          const timer = setInterval(() => {
            const ready = Array.from(document.querySelectorAll('a[href]')).some(link => notificationPath.test(absolute(link.getAttribute('href'))));
            if (ready || Date.now() - started > 8000) {
              clearInterval(timer);
              resolve();
            }
          }, 200);
        });
      }
      const seen = new Set();
      for (const link of document.querySelectorAll('a[href]')) {
        const detailURL = absolute(link.getAttribute('href'));
        const match = (() => { try { return new URL(detailURL).pathname.match(notificationPath); } catch (_) { return null; } })();
        if (!match || seen.has(match[1])) continue;
        seen.add(match[1]);
        const row = nearestRow(link, notificationPath);
        const rowText = normalize(row?.textContent);
        if (!rowText) continue;
        const metadataNode = Array.from(row?.querySelectorAll('p,small,span,div') || [])
          .map(node => normalize(node.textContent))
          .find(value => value.split('·').length >= 3 && value.length < 300);
        const metadata = (metadataNode || '').split('·').map(normalize).filter(Boolean);
        const courseName = metadata[0] || '';
        const senderName = metadata[1] || '';
        const dateText = metadata[2] || normalize(row?.querySelector('time')?.textContent);
        const course = courses.find(item => courseName && normalize(item.name).toLowerCase() === courseName.toLowerCase());
        let title = normalize(row?.querySelector('h1,h2,h3,h4,[class*=title]')?.textContent);
        if (!title || title === courseName) {
          const taskTitle = rowText.match(/^((?:New|Updated) Task:\s*.*?):\s+.+?\s+has just/i);
          const discussionTitle = rowText.match(/^(.*?):\s+.+?\s+has posted/i);
          title = normalize(taskTitle?.[1] || discussionTitle?.[1] || rowText.split(/(?<=[.!?])\s/)[0]);
        }
        messages.push({
          remoteIdentifier: match[1],
          title,
          bodyPreview: rowText,
          senderName,
          publishedDateText: dateToISO(dateText),
          isUnread: Boolean(row?.matches('[class*=unread],[data-unread=true]') || row?.querySelector('[class*=unread],[data-unread=true]')),
          courseIdentifier: course?.remoteIdentifier || null,
          detailURL
        });
      }
    }

    if (path.startsWith('/student/timetables')) {
      const table = Array.from(document.querySelectorAll('table')).find(item => /\bPeriod\b/i.test(item.innerText) && /\bMon\b/i.test(item.innerText));
      const rows = Array.from(table?.querySelectorAll('tr') || []);
      const headerCells = Array.from(rows[0]?.querySelectorAll('th,td') || []);
      const rangeText = normalize(document.querySelector('input[aria-label*=date i],input[value*=" - "]')?.value || document.querySelector('input[value*=" - "]')?.value);
      const fallbackYear = Number(rangeText.match(/\b(20\d{2})\b/)?.[1] || new Date().getFullYear());
      const headers = headerCells.slice(1).map((cell, index) => {
        const raw = normalize(cell.textContent);
        const match = raw.match(/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{1,2})/i);
        if (match) return `${match[1]} ${match[2]}, ${fallbackYear}`;
        const start = rangeText.match(/(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+(\d{1,2}),?\s+(20\d{2})/i);
        if (!start) return null;
        const date = new Date(`${start[1]} ${start[2]}, ${start[3]}`);
        date.setDate(date.getDate() + index);
        return date.toISOString().slice(0, 10);
      });
      const timePattern = /(\d{1,2}:\d{2}\s*(?:AM|PM))\s*-\s*(\d{1,2}:\d{2}\s*(?:AM|PM))/i;
      const normalizedCourseName = value => normalize(value)
        .replace(/^HS\s+/i, '')
        .replace(/\s*\(Grade\s+\d+\)\s*$/i, '')
        .trim();
      const toISO = (day, time) => {
        if (!day || !time) return null;
        const parsed = new Date(`${day} ${time}`);
        return Number.isNaN(parsed.valueOf()) ? null : parsed.toISOString();
      };
      const seen = new Set();
      for (const row of rows.slice(1)) {
        const cells = Array.from(row.querySelectorAll('th,td'));
        const period = normalize(cells[0]?.textContent);
        for (let index = 1; index < cells.length && index <= headers.length; index += 1) {
          const cell = cells[index];
          const cellText = normalize(cell?.textContent);
          const timeMatch = cellText.match(timePattern);
          if (!timeMatch) continue;
          let details = normalize(cellText.replace(timePattern, ''));
          const course = courses
            .map(item => ({ ...item, shortName: normalizedCourseName(item.name) }))
            .filter(item => item.shortName && details.toLowerCase().includes(item.shortName.toLowerCase()))
            .sort((a, b) => b.shortName.length - a.shortName.length)[0];
          const title = course?.shortName || normalize(details.replace(/\bGrade\s+\d+\b/i, '').replace(/^\d+\s+/, ''));
          const teachers = Array.from(new Set((course?.teacherNames || []).filter(name => details.toLowerCase().includes(normalize(name).toLowerCase()))));
          if (course) details = normalize(details.replace(new RegExp(course.shortName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'), ''));
          for (const teacher of teachers) details = normalize(details.replace(new RegExp(teacher.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'i'), ''));
          details = normalize(details.replace(/\bGrade\s+\d+\b/i, '').replace(/^\d+\s+/, ''));
          const startDateText = toISO(headers[index - 1], timeMatch[1]);
          const endDateText = toISO(headers[index - 1], timeMatch[2]);
          if (!startDateText || !endDateText || !title) continue;
          const remoteIdentifier = [headers[index - 1], period, course?.remoteIdentifier || title, timeMatch[1]].join('|');
          if (seen.has(remoteIdentifier)) continue;
          seen.add(remoteIdentifier);
          schedule.push({
            remoteIdentifier,
            title,
            courseIdentifier: course?.remoteIdentifier || null,
            startDateText,
            endDateText,
            location: details || null,
            teacherNames: teachers,
            attendanceStatus: null,
            detailURL: null
          });
        }
      }
    }
    return JSON.stringify({ messages, schedule });
    """#
}
