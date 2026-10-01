#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

enum PlanoraMenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 19, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            var transform = AffineTransform()
            transform.translate(x: 9.5, y: 9)
            transform.rotate(byDegrees: 12)
            transform.translate(x: -9.5, y: -9)
            let bars: [(CGFloat, CGFloat, CGFloat)] = [
                (205, 230, 190), (435, 230, 395), (140, 390, 450), (630, 390, 255),
                (125, 550, 175), (340, 550, 510), (190, 710, 315), (545, 710, 235)
            ]
            // Original Flow01...Flow08 icon geometry, without its background.
            for (x, y, width) in bars {
                    let path = NSBezierPath(roundedRect: NSRect(x: x / 1024 * 19,
                        y: (1024 - y - 102) / 1024 * 18, width: width / 1024 * 19,
                        height: 102 / 1024 * 18), xRadius: 36 / 1024 * 19, yRadius: 36 / 1024 * 18)
                    path.transform(using: transform)
                    path.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }()
}

struct MacMenuBarView: View {
    let store: PlanoraStore
    @Query(sort: \PlanoraTask.createdDate) private var tasks: [PlanoraTask]
    @Environment(\.openWindow) private var openWindow
    @State private var connection = ManageBacConnectionStorage.load()

    private var upcoming: [PlanoraTask] {
        Array(tasks.filter { !$0.isCompleted && !$0.isDeleted && !$0.isArchived }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }.prefix(5))
    }

    var body: some View {
        Group {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Planora").font(.headline)
                        Spacer()
                        Button("Open Planora", systemImage: "macwindow") { showMainWindow() }
                            .labelStyle(.iconOnly).help(String(localized: "Open Planora"))
                    }
                    Divider()
                    if upcoming.isEmpty {
                        Text("No Upcoming Tasks").foregroundStyle(.secondary)
                    }
                    ForEach(upcoming) { task in
                        Button { showMainWindow() } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(task.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                HStack {
                                    Text(task.subject).lineLimit(1)
                                    Spacer()
                                    if let deadline = task.deadline {
                                        Text(deadline, format: .dateTime.month().day().hour().minute())
                                    }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Divider()
                    if let connection {
                        HStack {
                            ForEach(ManageBacSyncMode.allCases) { mode in
                                Button {
                                    MacSyncRoute.request(.sync(connection, mode))
                                    showMainWindow()
                                } label: {
                                    Label(mode.title, systemImage: mode.symbol)
                                }
                            }
                        }
                        .buttonStyle(.glass)
                    } else {
                        Button("Connect Account", systemImage: "link") { showMainWindow() }
                    }
                    HStack {
                        if let date = connection?.lastSyncDate {
                            Text(date, format: .dateTime.hour().minute()).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Quit Planora") { NSApp.terminate(nil) }
                    }
                    .font(.caption)
                }
                .padding(18)
                .frame(width: 360)
        }
        .onReceive(NotificationCenter.default.publisher(for: .manageBacConnectionDidChange)) { _ in
            connection = ManageBacConnectionStorage.load()
        }
    }

    private func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}

@MainActor
enum MacSyncRoute {
    static var pending: ManageBacFlow?
    static let notification = Notification.Name("planora.open-sync")
    static func request(_ flow: ManageBacFlow) {
        pending = flow
        NotificationCenter.default.post(name: notification, object: nil)
    }
}
#endif
