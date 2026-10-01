#if os(macOS)
import AppKit
import SwiftUI

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
    func makeNSView(context: Context) -> WindowObserver { WindowObserver() }
    func updateNSView(_ view: WindowObserver, context: Context) {}

    final class WindowObserver: NSView {
        private static let mainWindows = NSHashTable<NSWindow>.weakObjects()
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
                MainActor.assumeIsolated { NSApp.setActivationPolicy(.regular) }
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
