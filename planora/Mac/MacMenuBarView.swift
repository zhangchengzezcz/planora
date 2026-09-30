#if os(macOS)
import AppKit
import SwiftData
import SwiftUI

enum PlanoraMenuBarIcon {
    static let image: NSImage = {
        let image = NSImage(size: NSSize(width: 19, height: 18), flipped: false) { _ in
            NSColor.black.setFill()
            for y in [2.0, 7.0, 12.0] {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: 2, y: y))
                path.line(to: NSPoint(x: 14, y: y))
                path.line(to: NSPoint(x: 17, y: y + 3))
                path.line(to: NSPoint(x: 5, y: y + 3))
                path.close()
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
    @State private var flow: ManageBacFlow?

    private var upcoming: [PlanoraTask] {
        Array(tasks.filter { !$0.isCompleted && !$0.isDeleted && !$0.isArchived }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }.prefix(5))
    }

    var body: some View {
        Group {
            if let flow {
                ManageBacConnectionFlowView(store: store, flow: flow) { snapshot in
                    connection = snapshot
                    self.flow = nil
                } onCancel: { self.flow = nil }
                .frame(width: 700, height: 640)
            } else {
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
                                Button { flow = .sync(connection, mode) } label: {
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
        }
        .onReceive(NotificationCenter.default.publisher(for: .manageBacConnectionDidChange)) { _ in
            connection = ManageBacConnectionStorage.load()
        }
    }

    private func showMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
#endif
