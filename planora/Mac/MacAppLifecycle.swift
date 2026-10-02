#if os(macOS)
import AppKit
import SwiftUI

@MainActor
final class MacMainWindowPresenter {
    static let shared = MacMainWindowPresenter()
    private let notificationCenter: NotificationCenter
    private let prepareApplication: () -> Void
    private let isApplicationActive: () -> Bool
    private let activateApplication: () -> Void
    private let showExistingWindow: () -> Bool
    private var pendingOpenWindow: (() -> Void)?
    private var activationObserver: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default,
         prepareApplication: @escaping () -> Void = {
             if NSApp.activationPolicy() != .regular { NSApp.setActivationPolicy(.regular) }
         },
         isApplicationActive: @escaping () -> Bool = { NSApp.isActive },
         activateApplication: @escaping () -> Void = { NSApp.activate() },
         showExistingWindow: @escaping () -> Bool = { MacMainWindowLifecycle.WindowObserver.showExistingWindow() }) {
        self.notificationCenter = notificationCenter
        self.prepareApplication = prepareApplication
        self.isApplicationActive = isApplicationActive
        self.activateApplication = activateApplication
        self.showExistingWindow = showExistingWindow
    }

    func request(openWindow: @escaping () -> Void) {
        pendingOpenWindow = openWindow
        prepareApplication()
        if isApplicationActive() {
            presentPendingWindow()
        } else if activationObserver == nil {
            // App activation is asynchronous. Do not restore a window in the previous app's Space.
            activationObserver = notificationCenter.addObserver(
                forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.presentPendingWindow() }
            }
            activateApplication()
        }
    }

    private func presentPendingWindow() {
        guard isApplicationActive(), let openWindow = pendingOpenWindow else { return }
        pendingOpenWindow = nil
        if let activationObserver { notificationCenter.removeObserver(activationObserver) }
        activationObserver = nil
        if !showExistingWindow() { openWindow() }
    }

    deinit {
        if let activationObserver { notificationCenter.removeObserver(activationObserver) }
    }
}

enum MacCloseBehavior: String, CaseIterable, Identifiable {
    case ask, background, quit
    var id: String { rawValue }
    static let key = "planora.window-close-behavior"
    var title: String {
        let chinese = PlanoraLocalization.preferredLocale.language.languageCode?.identifier == "zh"
        switch self {
        case .ask: return chinese ? "关闭时询问" : "Ask When Closing"
        case .background: return chinese ? "在菜单栏后台运行" : "Keep Running in Menu Bar"
        case .quit: return chinese ? "退出应用" : "Quit App"
        }
    }
}

@MainActor
struct MacMainWindowLifecycle: NSViewRepresentable {
    static var isTerminating = false
    static let didBecomeKey = Notification.Name("planora.main-window-did-become-key")
    static var canPresentMainContent: Bool {
        NSApp.isActive && WindowObserver.hasKeyMainWindow
    }
    func makeNSView(context: Context) -> WindowObserver { WindowObserver() }
    func updateNSView(_ view: WindowObserver, context: Context) {}

    final class WindowObserver: NSView {
        private static let mainWindows = NSHashTable<NSWindow>.weakObjects()
        static var hasKeyMainWindow: Bool {
            mainWindows.allObjects.contains(where: { $0.isKeyWindow })
        }
        static func showExistingWindow() -> Bool {
            let windows = mainWindows.allObjects.filter { $0.isVisible || $0.isMiniaturized }
            guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return false }
            if window.isMiniaturized {
                window.deminiaturize(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
            }
            return true
        }
        private var observers: [NSObjectProtocol] = []
        private weak var observedWindow: NSWindow?
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window, window !== observedWindow else { return }
            observers.forEach(NotificationCenter.default.removeObserver)
            observers.removeAll()
            observedWindow = window
            Self.mainWindows.add(window)
            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main
            ) { _ in
                MainActor.assumeIsolated {
                    if NSApp.activationPolicy() != .regular {
                        NSApp.setActivationPolicy(.regular)
                    }
                    NotificationCenter.default.post(name: MacMainWindowLifecycle.didBecomeKey, object: nil)
                }
            })
            observers.append(NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification, object: window, queue: .main
            ) { [weak window] _ in
                Task { @MainActor in
                    guard !Self.mainWindows.allObjects.contains(where: {
                        $0 !== window && $0.isVisible
                    }) else { return }
                    Self.handleLastWindowClosed()
                }
            })
        }

        private static func handleLastWindowClosed() {
            guard !MacMainWindowLifecycle.isTerminating else { return }
            let defaults = UserDefaults.standard
            var behavior = MacCloseBehavior(rawValue: defaults.string(forKey: MacCloseBehavior.key) ?? "ask") ?? .ask
            if behavior == .ask {
                let chinese = PlanoraLocalization.preferredLocale.language.languageCode?.identifier == "zh"
                let alert = NSAlert()
                alert.messageText = chinese ? "关闭窗口后，Planora 要继续运行吗？" : "Keep Planora running after closing the window?"
                alert.informativeText = chinese
                    ? "后台运行会隐藏 Dock 图标，并保留菜单栏。你可以稍后在设置中更改。"
                    : "Background mode hides the Dock icon and keeps the menu bar available. You can change this in Settings."
                alert.addButton(withTitle: MacCloseBehavior.background.title)
                alert.addButton(withTitle: MacCloseBehavior.quit.title)
                behavior = alert.runModal() == .alertFirstButtonReturn ? .background : .quit
                defaults.set(behavior.rawValue, forKey: MacCloseBehavior.key)
            }
            if behavior == .background { NSApp.setActivationPolicy(.accessory) }
            else { NSApp.terminate(nil) }
        }

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }
    }
}
#endif
