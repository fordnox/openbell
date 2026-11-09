import AppKit
import SwiftUI

struct AboutSettingsPane: View {
    @ObservedObject private var updater = UpdaterManager.shared

    var body: some View {
        Form {
            Section {
                HStack(alignment: .center, spacing: 16) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("OpenBell")
                            .font(.largeTitle.bold())
                        Text(AppVersion.displayString)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                        Text("Stock market open and close countdowns.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // App Store copies are updated by the store, so there's nothing to show.
            if !UpdaterManager.isAppStoreBuild {
                Section {
                    Toggle("Automatically check for updates", isOn: Binding(
                        get: { updater.isSupported && updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    ))
                    .disabled(!updater.isSupported)

                    Button("Check for Updates…") { updater.checkForUpdates() }
                        .disabled(!updater.canCheckForUpdates)
                } header: {
                    Text("Updates")
                } footer: {
                    if !updater.isSupported {
                        Text("Updates are turned off in debug builds.")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Project") {
                Text("Countdowns to stock market opens and closes in the menu bar, the app window, and desktop widgets.")
                    .foregroundStyle(.secondary)
                Link("camosec.com", destination: URL(string: "https://camosec.com")!)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
