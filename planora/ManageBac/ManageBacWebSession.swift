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
    var programmeText: String?
    var completedStepCount = 0

    @ObservationIgnored var onSnapshotReady: ((ManageBacSyncSnapshot) throws -> ManageBacImportSummary)?
    @ObservationIgnored private(set) lazy var webView: WKWebView = makeWebView()
    @ObservationIgnored private var mode: Mode = .interactive
    @ObservationIgnored private var schoolHost: String?
    @ObservationIgnored private var taskViews = ["upcoming", "overdue", "completed"]
    @ObservationIgnored private var currentTaskViewIndex = 0
    @ObservationIgnored private var currentCourseIndex = 0
    @ObservationIgnored private var isHandlingPage = false

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
        webView.stopLoading()
        phase = .failed(.cancelled)
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
        guard !isHandlingPage else { return }
        isHandlingPage = true
        Task {
            defer { isHandlingPage = false }
            await handleLoadedPage()
        }
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
        programmeText = nil
        schoolHost = nil
        currentTaskViewIndex = 0
        currentCourseIndex = 0
        completedStepCount = 0
        isHandlingPage = false
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
                return
            }
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
                currentCourseIndex = 0
                loadNextCourseOrTasks()
            } catch {
                phase = .failed(.pageStructureChanged)
            }

        case .loadingUnits:
            do {
                let payload: CourseDetailPayload = try await decodeJavaScript(
                    Self.courseDetailScript,
                    arguments: ["courseIdentifier": courses[currentCourseIndex].remoteIdentifier]
                )
                courses[currentCourseIndex].teacherNames = payload.teacherNames
                if courses[currentCourseIndex].programmeText == nil {
                    courses[currentCourseIndex].programmeText = payload.programmeText
                }
                units.append(contentsOf: payload.units)
                currentCourseIndex += 1
                loadNextCourseOrTasks()
            } catch {
                phase = .failed(.pageStructureChanged)
            }

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
                    finishImport()
                }
            } catch {
                phase = .failed(.pageStructureChanged)
            }
        default:
            break
        }
    }

    private func loadNextCourseOrTasks() {
        if currentCourseIndex < courses.count,
           let detailURL = courses[currentCourseIndex].detailURL,
           let url = URL(string: detailURL) {
            phase = .loadingUnits
            load(url)
        } else {
            completedStepCount = 4
            currentTaskViewIndex = 0
            phase = .loadingTasks
            loadStudentPath("/student/tasks_and_deadlines?view=\(taskViews[0])")
        }
    }

    private func finishImport() {
        guard let schoolHost, let onSnapshotReady else {
            phase = .failed(.invalidResponse)
            return
        }
        do {
            phase = .comparing
            completedStepCount = 6
            phase = .importing
            let snapshot = ManageBacSyncSnapshot(
                schoolHost: schoolHost,
                programmeText: programmeText,
                courses: courses,
                units: units,
                tasks: records
            )
            let summary = try onSnapshotReady(snapshot)
            let detection = ManageBacProgrammeDetector.detect(
                programmeText: programmeText,
                courses: courses
            )
            completedStepCount = 8
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
        webView.load(URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData))
    }

    private func isAuthenticatedStudentPage() async -> Bool {
        guard webView.url?.path.hasPrefix("/student/") == true else { return false }
        let result = try? await webView.callAsyncJavaScript(
            "return Boolean(location.pathname.startsWith('/student/') && (document.querySelector('a[href*=\"/student/tasks_and_deadlines\"]') || document.querySelector('a[href*=\"/student/classes\"]')));",
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
        var programmeText: String?
        var teacherNames: [String]
        var units: [ManageBacUnitRecord]
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

    private static let courseDetailScript = #"""
    const normalize = value => (value || '').replace(/\s+/g, ' ').trim();
    const absolute = value => { try { return new URL(value, location.origin).href; } catch (_) { return ''; } };
    const courseID = courseIdentifier;
    const teachers = Array.from(document.querySelectorAll('[class*=teacher], [data-role=teacher], a[href*="/users/"]'))
      .map(node => normalize(node.textContent)).filter(value => value && value.length < 100);
    const teacherNames = [...new Set(teachers)];
    const units = [];
    const seen = new Set();
    for (const link of document.querySelectorAll('a[href]')) {
      const href = link.getAttribute('href') || '';
      if (!/\/units?\//i.test(href)) continue;
      const url = (() => { try { return new URL(href, location.origin); } catch (_) { return null; } })();
      const title = normalize(link.textContent);
      const remoteIdentifier = url?.pathname.replace(/\/$/, '').split('/').pop() || href;
      if (!title || !remoteIdentifier || seen.has(remoteIdentifier)) continue;
      seen.add(remoteIdentifier);
      const container = link.closest('article,li,tr,.card,[class*=unit]') || link.parentElement;
      const times = Array.from(container?.querySelectorAll('time') || []);
      const progressText = normalize(container?.querySelector('[class*=progress]')?.textContent);
      const progressMatch = progressText.match(/(\d+(?:\.\d+)?)\s*%/);
      units.push({
        remoteIdentifier,
        courseIdentifier: courseID,
        title,
        detailURL: absolute(href),
        startDateText: times[0]?.getAttribute('datetime') || null,
        endDateText: times[1]?.getAttribute('datetime') || null,
        officialProgress: progressMatch ? Number(progressMatch[1]) / 100 : null
      });
    }
    const programmeText = normalize(document.querySelector('[class*=programme], [class*=program], [class*=year-group], nav[aria-label*=breadcrumb]')?.textContent) || null;
    return JSON.stringify({ programmeText, teacherNames, units });
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
}
