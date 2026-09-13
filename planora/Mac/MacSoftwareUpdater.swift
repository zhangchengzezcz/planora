#if os(macOS)
import Combine
import Sparkle
import SwiftUI

@MainActor
final class MacSoftwareUpdater: ObservableObject {
    static let shared = MacSoftwareUpdater()

    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var automaticallyDownloadsUpdates = false
    @Published private(set) var lastUpdateCheckDate: Date?

    private let controller: SPUStandardUpdaterController

    private init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        let updater = controller.updater
        updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
        updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
        updater.publisher(for: \.automaticallyDownloadsUpdates).assign(to: &$automaticallyDownloadsUpdates)
        updater.publisher(for: \.lastUpdateCheckDate).assign(to: &$lastUpdateCheckDate)
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        controller.checkForUpdates(nil)
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func setAutomaticDownloads(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
    }
}

struct MacSoftwareUpdateSettings: View {
    @ObservedObject private var updater = MacSoftwareUpdater.shared

    var body: some View {
        Form {
            Section("Software Update") {
                LabeledContent("Version", value: version)
                if let date = updater.lastUpdateCheckDate {
                    LabeledContent("Last Checked") {
                        Text(date, format: .dateTime.month().day().hour().minute())
                    }
                }
                Button("Check for Updates…", systemImage: "arrow.triangle.2.circlepath") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
            Section {
                Toggle("Automatically Check for Updates", isOn: Binding(
                    get: { updater.automaticallyChecksForUpdates },
                    set: updater.setAutomaticChecks
                ))
                Toggle("Download Updates Automatically", isOn: Binding(
                    get: { updater.automaticallyDownloadsUpdates },
                    set: updater.setAutomaticDownloads
                ))
                .disabled(!updater.automaticallyChecksForUpdates)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Software Update")
    }

    private var version: String {
        let info = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "-") (\(info["CFBundleVersion"] as? String ?? "-"))"
    }
}
#endif
