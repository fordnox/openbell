import AppKit
import SwiftUI

enum SettingsKey {
    static let showDockIcon = "showDockIcon"
    static let menuBarMarket = "menuBarMarket"
    static let displayMode = "displayMode"
    static let enabledMarkets = "enabledMarkets"
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
    // Touching the shared instance here creates Sparkle's updater controller before launch finishes.
    @MainActor private let updaterManager = UpdaterManager.shared

    // SwiftUI sets .regular during launch, so apply the preference afterwards.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(DockIcon.isShown ? .regular : .accessory)
        SharedSettings.migrateFromStandardDefaults()
        MainActor.assumeIsolated { updaterManager.start() }
    }
}

/// Shows the Dock icon while a window like Settings is open, so a menu bar-only app can
/// come to the front; restores the user's Dock icon preference once the last one closes.
@MainActor
enum AppActivationPolicy {
    private static var count = 0

    static func enter() {
        count += 1
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func leave() {
        count = max(0, count - 1)
        guard count == 0 else { return }
        Task { @MainActor in
            NSApp.setActivationPolicy(DockIcon.isShown ? .regular : .accessory)
        }
    }
}
