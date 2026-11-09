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
    // SwiftUI sets .regular during launch, so apply the preference afterwards.
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(DockIcon.isShown ? .regular : .accessory)
    }
}

struct SettingsView: View {
    @AppStorage(SettingsKey.showDockIcon) private var showDockIcon = true
    @AppStorage(SettingsKey.menuBarMarket) private var menuBarMarketID = Market.nyse.id
    @AppStorage(SettingsKey.displayMode) private var mode: DisplayMode = .list
    @AppStorage(SettingsKey.enabledMarkets) private var enabledMarkets = ""

    private var enabledIDs: Set<String> { Market.enabledIDs(from: enabledMarkets) }

    private func isEnabled(_ market: Market) -> Binding<Bool> {
        Binding {
            enabledIDs.contains(market.id)
        } set: { on in
            var ids = enabledIDs
            if on { ids.insert(market.id) } else { ids.remove(market.id) }
            guard !ids.isEmpty else { return }
            enabledMarkets = Market.encode(enabledIDs: ids)
            if !ids.contains(menuBarMarketID) {
                menuBarMarketID = Market.all.enabled(ids).first?.id ?? Market.nyse.id
            }
        }
    }

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
                    ForEach(Market.all.enabled(enabledIDs)) { Text($0.name).tag($0.id) }
                }
                Picker("Default view", selection: $mode) {
                    ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Markets") {
                ForEach(Market.all) { market in
                    let isOnlyOne = enabledIDs == [market.id]
                    Toggle(isOn: isEnabled(market)) {
                        HStack(spacing: 8) {
                            MarketBadge(market: market, size: 10)
                            Text(market.name)
                            Text(market.fullName).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(isOnlyOne)
                }
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
