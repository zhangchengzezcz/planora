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
            for row in 0..<4 {
                let y = CGFloat(row) * 3.8 + 0.8
                let widths: [CGFloat] = row.isMultiple(of: 2) ? [4.2, 10.2] : [10.2, 4.2]
                var x: CGFloat = 1.8
                for width in widths {
                    let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: width, height: 2.8), xRadius: 1, yRadius: 1)
                    path.transform(using: transform)
                    path.fill()
                    x += width + 1.6
                }
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
