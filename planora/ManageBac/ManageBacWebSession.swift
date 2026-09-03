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
    @ObservationIgnored private var taskViews = ["upcoming", "overdue", "completed"]
    @ObservationIgnored private var currentTaskViewIndex = 0
    @ObservationIgnored private var isHandlingPage = false
    @ObservationIgnored private var needsAnotherPageCheck = false
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
        authenticationProbeTask?.cancel()
        pageLoadWatchdogTask?.cancel()
        webView.stopLoading()
        phase = .failed(.cancelled)
    }

    func teardown() {
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
        webView.stopLoading()
        self.mode = mode
        courses = []
        units = []
        records = []
        messages = []
        schedule = []
        programmeText = nil
        schoolHost = nil
        currentTaskViewIndex = 0
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
        Task {
            repeat {
                needsAnotherPageCheck = false
                await handleLoadedPage()
            } while needsAnotherPageCheck
            isHandlingPage = false
        }
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
                    self.enqueuePageCheck()
                    return
                }
            }
        }
    }

    private func handleLoadedPage() async {
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
            guard await isAuthenticatedStudentPage() else {
                phase = mode == .silent ? .needsLogin : .authenticating
                scheduleAuthenticationProbesIfNeeded()
                return
            }
            authenticationProbeTask?.cancel()
            authenticationProbeTask = nil
            schoolHost = host
            completedStepCount = 1
            phase = .loadingCourses
            loadStudentPath("/student/classes/all")

        case .loadingCourses:
            do {
                let payload: CourseScanPayload = try await decodeJavaScript(Self.courseScript)
                courses = payload.courses
                programmeText = payload.programmeText
                completedStepCount = 2
                phase = .identifyingCurriculum
                completedStepCount = 3
                phase = .loadingUnits
                await readCourseDetails()
                completedStepCount = 4
                currentTaskViewIndex = 0
                phase = .loadingTasks
                loadStudentPath("/student/tasks_and_deadlines?view=\(taskViews[0])")
            } catch {
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
                    phase = .loadingWorkspace
                    loadStudentPath("/student/home")
                }
            } catch {
                phase = .failed(.pageStructureChanged)
            }
        case .loadingWorkspace:
            do {
                let payload: WorkspaceScanPayload = try await decodeJavaScript(Self.workspaceScript)
                messages = payload.messages
                schedule = payload.schedule
                completedStepCount = 6
                finishImport()
            } catch {
                // Messages and timetables are optional school modules. A layout
                // change here must not discard the core course/task snapshot.
                messages = []
                schedule = []
                completedStepCount = 6
                finishImport()
            }
        default:
            break
        }
    }

    private func readCourseDetails() async {
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
            messages = []
            schedule = []
            completedStepCount = 6
            finishImport()
        case .loadingTasks:
            currentTaskViewIndex += 1
            if currentTaskViewIndex < taskViews.count {
                loadStudentPath("/student/tasks_and_deadlines?view=\(taskViews[currentTaskViewIndex])")
            } else {
                completedStepCount = 5
                phase = .loadingWorkspace
                loadStudentPath("/student/home")
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

    private static let courseScript = #"""
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = value => { try { return new URL(value, location.origin).href; } catch (_) { return ''; } };
    const courses = [];
    const seen = new Set();
    for (const link of document.querySelectorAll('a[href]')) {
      const href = link.getAttribute('href') || '';
      const url = (() => { try { return new URL(href, location.origin); } catch (_) { return null; } })();
      if (!url || !/^\/student\/classes\/[^/?#]+\/?$/.test(url.pathname) || /\/(all|my)\/?$/.test(url.pathname)) continue;
      const name = normalize(link.textContent);
      const remoteIdentifier = url.pathname.replace(/\/$/, '').split('/').pop();
      if (!name || !remoteIdentifier || seen.has(remoteIdentifier)) continue;
      seen.add(remoteIdentifier);
      const container = link.closest('article,li,tr,.card,[class*=class]') || link.parentElement;
      const teacherNames = Array.from(container?.querySelectorAll('[class*=teacher], [data-role=teacher]') || []).map(node => normalize(node.textContent)).filter(Boolean);
      courses.push({ remoteIdentifier, name, teacherNames, detailURL: absolute(href), programmeText: null });
    }
    const main = document.querySelector('main');
    const programmeText = normalize(main?.querySelector('[class*=programme], [class*=program], [class*=year-group], nav[aria-label*=breadcrumb]')?.textContent) || null;
    return JSON.stringify({ programmeText, courses });
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

    private static let taskScript = #"""
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = value => { try { return new URL(value, location.origin).href; } catch (_) { return ''; } };
    const currentSourceView = sourceView;
    const candidates = [];
    const seen = new Set();
    for (const link of document.querySelectorAll('a[href]')) {
      const href = link.getAttribute('href') || '';
      const path = (() => { try { return new URL(href, location.origin).pathname; } catch (_) { return href; } })();
      const dataID = link.dataset.taskId || link.dataset.deadlineId || '';
      if (!/\/(tasks|deadlines)\/\d+/.test(path) && !/\/tasks_and_deadlines\/\d+/.test(path) && !dataID) continue;
      const container = link.closest('[data-task-id], [data-deadline-id], article, tr, li, .card, .task, .deadline') || link.parentElement;
      const title = normalize(link.textContent || container?.querySelector('h1,h2,h3,h4,[class*=title]')?.textContent);
      if (!title) continue;
      const detailURL = absolute(href);
      const remoteIdentifier = dataID || detailURL;
      if (!remoteIdentifier || seen.has(remoteIdentifier)) continue;
      seen.add(remoteIdentifier);
      const time = container?.querySelector('time');
      const dateNode = time || container?.querySelector('[data-deadline], [data-date], [class*=deadline], [class*=due], [class*=date]');
      const deadlineText = time?.getAttribute('datetime') || dateNode?.getAttribute('data-deadline') || dateNode?.getAttribute('data-date') || normalize(dateNode?.textContent) || null;
      const classLink = container?.querySelector('a[href*="/student/classes/"]');
      const classURL = classLink ? new URL(classLink.getAttribute('href'), location.origin) : null;
      const courseIdentifier = classURL?.pathname.replace(/\/$/, '').split('/').pop() || null;
      const unitLink = container?.querySelector('a[href*="/unit/"], a[href*="/units/"]');
      const unitURL = unitLink ? new URL(unitLink.getAttribute('href'), location.origin) : null;
      const unitIdentifier = unitURL?.pathname.replace(/\/$/, '').split('/').pop() || null;
      candidates.push({
        remoteIdentifier,
        title,
        subject: normalize(classLink?.textContent),
        deadlineText,
        detailURL,
        sourceView: currentSourceView,
        courseIdentifier,
        unitIdentifier,
        remoteStatus: ['upcoming','overdue','completed'].includes(currentSourceView) ? currentSourceView : 'unknown'
      });
    }
    const main = document.querySelector('main');
    const text = normalize(main?.innerText).toLowerCase();
    const emptyState = text.includes('no upcoming') || text.includes('no overdue') || text.includes('no completed') || text.includes('no tasks or deadlines');
    const pageRecognized = Boolean(main && (emptyState || candidates.length > 0 || location.pathname.includes('tasks_and_deadlines')));
    return JSON.stringify({ records: candidates, pageRecognized });
    """#

    private static let workspaceScript = #"""
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = value => { try { return new URL(value, location.origin).href; } catch (_) { return ''; } };
    const messages = [];
    const messageIDs = new Set();
    for (const link of document.querySelectorAll('a[href]')) {
      const href = link.getAttribute('href') || '';
      if (!/(messages|discussions|message_board|notifications)/i.test(href)) continue;
      const container = link.closest('article,li,tr,.card,[class*=message],[class*=notification]') || link.parentElement;
      const title = normalize(link.textContent || container?.querySelector('h1,h2,h3,h4,[class*=title]')?.textContent);
      if (!title) continue;
      const detailURL = absolute(href);
      const remoteIdentifier = link.dataset.messageId || container?.dataset?.messageId || detailURL;
      if (!remoteIdentifier || messageIDs.has(remoteIdentifier)) continue;
      messageIDs.add(remoteIdentifier);
      const time = container?.querySelector('time');
      const sender = container?.querySelector('[class*=author],[class*=sender],[data-role=author]');
      const classLink = container?.querySelector('a[href*="/student/classes/"]');
      const classURL = classLink ? new URL(classLink.getAttribute('href'), location.origin) : null;
      messages.push({
        remoteIdentifier,
        title,
        bodyPreview: normalize(container?.querySelector('p,[class*=body],[class*=preview]')?.textContent),
        senderName: normalize(sender?.textContent),
        publishedDateText: time?.getAttribute('datetime') || normalize(time?.textContent) || null,
        isUnread: Boolean(container?.matches('[class*=unread],[data-unread=true]') || container?.querySelector('[class*=unread],[data-unread=true]')),
        courseIdentifier: classURL?.pathname.replace(/\/$/, '').split('/').pop() || null,
        detailURL
      });
    }

    const schedule = [];
    const scheduleIDs = new Set();
    const scheduleNodes = document.querySelectorAll('[data-start],[data-start-time],[class*=timetable] [class*=event],[class*=schedule] [class*=event],[class*=lesson]');
    for (const node of scheduleNodes) {
      const times = Array.from(node.querySelectorAll('time'));
      const startDateText = node.dataset.start || node.dataset.startTime || times[0]?.getAttribute('datetime');
      const endDateText = node.dataset.end || node.dataset.endTime || times[1]?.getAttribute('datetime') || startDateText;
      const title = normalize(node.querySelector('h1,h2,h3,h4,[class*=title],[class*=subject]')?.textContent || node.textContent);
      if (!title || !startDateText || !endDateText) continue;
      const link = node.querySelector('a[href]');
      const detailURL = absolute(link?.getAttribute('href') || '');
      const remoteIdentifier = node.dataset.eventId || node.dataset.lessonId || [title,startDateText,endDateText].join('|');
      if (scheduleIDs.has(remoteIdentifier)) continue;
      scheduleIDs.add(remoteIdentifier);
      const classLink = node.querySelector('a[href*="/student/classes/"]');
      const classURL = classLink ? new URL(classLink.getAttribute('href'), location.origin) : null;
      const teachers = Array.from(node.querySelectorAll('[class*=teacher],[data-role=teacher]')).map(item => normalize(item.textContent)).filter(Boolean);
      schedule.push({
        remoteIdentifier,
        title,
        courseIdentifier: classURL?.pathname.replace(/\/$/, '').split('/').pop() || null,
        startDateText,
        endDateText,
        location: normalize(node.querySelector('[class*=location],[class*=room],[data-role=location]')?.textContent) || null,
        teacherNames: [...new Set(teachers)],
        attendanceStatus: normalize(node.querySelector('[class*=attendance],[data-attendance]')?.textContent) || null,
        detailURL: detailURL || null
      });
    }
    return JSON.stringify({ messages, schedule });
    """#
}
