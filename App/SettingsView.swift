import AppKit
import SwiftUI

enum SettingsKey {
    static let showDockIcon = "showDockIcon"
    static let menuBarMarket = "menuBarMarket"
    static let displayMode = "displayMode"
}

enum DockIcon {
    static var isShown: Bool {
        let defaults = UserDefaults.standard
        // bool(forKey:) also understands "NO"/"0" strings (e.g. `-showDockIcon NO` launch args).
        return defaults.object(forKey: SettingsKey.showDockIcon) == nil ? true : defaults.bool(forKey: SettingsKey.showDockIcon)
    }

    /// `.regular` shows the Dock icon and app menu; `.accessory` runs as a menu bar-only app.
    @MainActor
    static func apply(_ show: Bool) {
        let policy: NSApplication.ActivationPolicy = show ? .regular : .accessory
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
        // Switching to .accessory deactivates the app and can push its windows
        // behind others; bring us (and the Settings window) back to the front.
        DispatchQueue.main.async {
            NSApp.activate()
            NSApp.keyWindow?.makeKeyAndOrderFront(nil)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    // SwiftUI sets .regular during launch, so apply the preference afterwards.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(DockIcon.isShown ? .regular : .accessory)
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.showDockIcon) private var showDockIcon = true
    @AppStorage(SettingsKey.menuBarMarket) private var menuBarMarketID = Market.nyse.id
    @AppStorage(SettingsKey.displayMode) private var mode: DisplayMode = .list

    var body: some View {
        Form {
            Section {
                Toggle("Show icon in Dock", isOn: $showDockIcon)
                    .onChange(of: showDockIcon) { _, show in DockIcon.apply(show) }
            } footer: {
                Text("When hidden, OpenBell runs from the menu bar only.")
                    .foregroundStyle(.secondary)
            }

            Section {
                Picker("Menu bar market", selection: $menuBarMarketID) {
                    ForEach(Market.all) { Text($0.name).tag($0.id) }
                }
                Picker("Default view", selection: $mode) {
                    ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Opens Settings and brings it to the front — needed when there is no Dock icon,
/// otherwise the window can open behind other apps.
struct SettingsButton: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Settings…") {
            NSApp.activate()
            openSettings()
        }
    }
}
