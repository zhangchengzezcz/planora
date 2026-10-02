#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

enum PlanoraMenuBarIcon {
    static let size = NSSize(width: 22, height: 18)
    static let image: NSImage = {
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.setFill()
            let artwork = NSBezierPath()
            let bars: [(CGFloat, CGFloat, CGFloat)] = [
                (205, 230, 190), (435, 230, 395), (140, 390, 450), (630, 390, 255),
                (125, 550, 175), (340, 550, 510), (190, 710, 315), (545, 710, 235)
            ]
            // Original Flow01...Flow08 icon geometry, without its background.
            for (x, y, width) in bars {
                artwork.append(NSBezierPath(roundedRect: NSRect(x: x,
                    y: 1024 - y - 102, width: width, height: 102),
                    xRadius: 36, yRadius: 36))
            }
            var rotation = AffineTransform()
            rotation.rotate(byDegrees: 12)
            artwork.transform(using: rotation)
            let bounds = artwork.bounds
            let scale = min((size.width - 1) / bounds.width, (size.height - 1) / bounds.height)
            var placement = AffineTransform()
            placement.translate(x: size.width / 2, y: size.height / 2)
            placement.scale(scale)
            placement.translate(x: -bounds.midX, y: -bounds.midY)
            artwork.transform(using: placement)
            artwork.fill()
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
                        Button {
                            MacTaskRoute.request(task.id)
                            showMainWindow()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(alignment: .firstTextBaseline, spacing: 6) {
                                    Text(task.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    Spacer(minLength: 4)
                                    if task.displayPriority == .high {
                                        Label(task.priorityDisplayTitle, systemImage: "flag.fill")
                                            .labelStyle(.iconOnly)
                                            .font(.caption)
                                            .foregroundStyle(Color.planoraAmber)
                                            .help(task.priorityDisplayTitle)
                                    }
                                    Text(task.priorityDisplayTitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                HStack {
                                    Text(task.subject).lineLimit(1)
                                    Spacer()
                                    if let deadline = task.deadline {
                                        Text(deadline, format: .dateTime.month().day().hour().minute())
                                            .foregroundStyle(deadline < Date() ? Color.planoraAmber : Color.secondary)
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
                            HStack(spacing: 4) {
                                Text(String(localized: "Last Sync"))
                                Text(date, format: .dateTime.hour().minute())
                            }
                            .foregroundStyle(.secondary)
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
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
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

@MainActor
enum MacTaskRoute {
    private static var pendingTaskID: UUID?
    static let notification = Notification.Name("planora.open-task")

    static func request(_ taskID: UUID, notificationCenter: NotificationCenter = .default) {
        pendingTaskID = taskID
        notificationCenter.post(name: notification, object: nil)
    }

    static func takePendingTask() -> UUID? {
        defer { pendingTaskID = nil }
        return pendingTaskID
    }
}
#endif
