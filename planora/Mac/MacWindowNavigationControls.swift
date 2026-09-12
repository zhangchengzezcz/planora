#if os(macOS)
import AppKit
import SwiftUI

struct MacWindowNavigationControls: NSViewRepresentable {
    var toggleSidebar: () -> Void
    var createTask: () -> Void

    func makeNSView(context: Context) -> WindowAnchor {
        WindowAnchor(controls: self)
    }

    func updateNSView(_ view: WindowAnchor, context: Context) {
        view.host.rootView = AnyView(buttons)
    }

    static func dismantleNSView(_ view: WindowAnchor, coordinator: ()) {
        view.detach()
    }

    private var buttons: some View {
        HStack(spacing: 0) {
            Button(action: toggleSidebar) {
                Image(systemName: "sidebar.leading").frame(width: 38, height: 36)
            }
            .help(String(localized: "Toggle Sidebar"))
            .accessibilityLabel(String(localized: "Toggle Sidebar"))
            Divider().frame(height: 18)
            Button(action: createTask) {
                Image(systemName: "plus").frame(width: 38, height: 36)
            }
            .help(String(localized: "New Task"))
            .accessibilityLabel(String(localized: "New Task"))
        }
        .font(.system(size: 17))
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: Capsule())
        .padding(.horizontal, 8)
        .frame(width: 96, height: 46)
    }

    final class WindowAnchor: NSView {
        let accessory = NSTitlebarAccessoryViewController()
        let host: NSHostingView<AnyView>
        private weak var attachedWindow: NSWindow?

        init(controls: MacWindowNavigationControls) {
            host = NSHostingView(rootView: AnyView(controls.buttons))
            super.init(frame: .zero)
            accessory.layoutAttribute = .left
            host.frame = NSRect(x: 0, y: 0, width: 96, height: 46)
            accessory.view = host
        }

        required init?(coder: NSCoder) { nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard window !== attachedWindow else { return }
            detach()
            guard let window else { return }
            // Let AppKit position the control beside traffic lights in every window mode.
            window.addTitlebarAccessoryViewController(accessory)
            attachedWindow = window
        }

        func detach() {
            if let window = attachedWindow,
               let index = window.titlebarAccessoryViewControllers.firstIndex(of: accessory) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            attachedWindow = nil
        }
    }
}
#endif
