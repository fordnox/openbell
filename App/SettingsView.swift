import AppKit
import SwiftUI

enum SettingsKey {
    static let showDockIcon = "showDockIcon"
    static let menuBarMarket = "menuBarMarket"
    static let displayMode = "displayMode"
    static let enabledMarkets = "enabledMarkets"
    static let showDialCards = "showDialCards"
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

// MARK: - Settings window

enum SettingsPane: String, CaseIterable, Identifiable {
    case general = "General", appearance = "Appearance", markets = "Markets", widgets = "Widgets", about = "About"
    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: "gearshape.fill"
        case .appearance: "paintbrush.fill"
        case .markets: "chart.line.uptrend.xyaxis"
        case .widgets: "square.grid.2x2.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .appearance: .blue
        case .markets: .green
        case .widgets: .purple
        case .about: .orange
        }
    }
}

/// System Settings–style window: panes in a sidebar on the left, the selected pane's form on the right.
struct SettingsView: View {
    @State private var pane: SettingsPane = .general

    var body: some View {
        NavigationSplitView {
            List(SettingsPane.allCases, selection: $pane) { pane in
                Label {
                    Text(pane.rawValue)
                } icon: {
                    Image(systemName: pane.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(pane.tint.gradient))
                }
                .tag(pane)
            }
            .navigationSplitViewColumnWidth(190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            Group {
                switch pane {
                case .general: GeneralSettings()
                case .appearance: AppearanceSettings()
                case .markets: MarketsSettings()
                case .widgets: WidgetsSettings()
                case .about: AboutSettings()
                }
            }
            .formStyle(.grouped)
            .navigationTitle(pane.rawValue)
        }
        .frame(width: 700, height: 500)
    }
}

private struct GeneralSettings: View {
    @AppStorage(SettingsKey.showDockIcon) private var showDockIcon = true
    @AppStorage(SettingsKey.menuBarMarket) private var menuBarMarketID = Market.nyse.id
    @AppStorage(SettingsKey.enabledMarkets) private var enabledMarkets = ""

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
                    ForEach(Market.all.enabled(Market.enabledIDs(from: enabledMarkets))) { Text($0.name).tag($0.id) }
                }
            } footer: {
                Text("The menu bar shows this market's countdown to its next open or close.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AppearanceSettings: View {
    @AppStorage(SettingsKey.displayMode) private var mode: DisplayMode = .list
    @AppStorage(SettingsKey.showDialCards) private var showDialCards = true

    var body: some View {
        Form {
            Section {
                Picker("Default view", selection: $mode) {
                    ForEach(DisplayMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("List shows each market's countdown; Dial shows the day's sessions on a 24-hour clock.")
                    .foregroundStyle(.secondary)
            }

            Section("Dial") {
                Toggle("Show market cards under the dial", isOn: $showDialCards)
            }
        }
    }
}

private struct MarketsSettings: View {
    @AppStorage(SettingsKey.menuBarMarket) private var menuBarMarketID = Market.nyse.id
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
                ForEach(Market.all) { market in
                    Toggle(isOn: isEnabled(market)) {
                        HStack(spacing: 8) {
                            MarketBadge(market: market, size: 10)
                            Text(market.name)
                            Text(market.fullName).foregroundStyle(.secondary)
                        }
                    }
                    .disabled(enabledIDs == [market.id])
                }
            } header: {
                Text("Shown markets")
            } footer: {
                Text("Turned-on markets appear in the list, on the dial, and in the menu bar picker. At least one must stay on.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct WidgetsSettings: View {
    private struct WidgetInfo: Identifiable {
        let name: String, size: String, symbol: String, detail: String
        var id: String { name }
    }

    private let widgets = [
        WidgetInfo(name: "Market Countdown", size: "Small", symbol: "square.fill",
                   detail: "One market with a big countdown to its next open or close. Right-click the widget and choose Edit Widget to pick the market."),
        WidgetInfo(name: "Markets", size: "Medium", symbol: "rectangle.fill",
                   detail: "Open/closed status and countdowns for the default markets."),
        WidgetInfo(name: "Sessions Dial", size: "Large", symbol: "square.fill",
                   detail: "The 24-hour sessions dial with countdown cards."),
    ]

    var body: some View {
        Form {
            Section {
                ForEach(widgets) { w in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: w.symbol)
                            .font(.system(size: w.size == "Large" ? 22 : w.size == "Medium" ? 18 : 14))
                            .foregroundStyle(.purple.gradient)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(w.name).fontWeight(.medium)
                                Text(w.size)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(.quaternary))
                            }
                            Text(w.detail)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 2)
                }
            } header: {
                Text("Available widgets")
            } footer: {
                Text("OpenBell's widgets keep counting down on your desktop and in Notification Center, even when the app's window is closed.")
                    .foregroundStyle(.secondary)
            }

            Section("Add a widget to your desktop") {
                step(1, "Right-click an empty area of the desktop and choose **Edit Widgets…**")
                step(2, "Search for **OpenBell** in the widget gallery.")
                step(3, "Drag a widget onto the desktop, or click it to add it.")
                step(4, "To change which market a Market Countdown widget shows, right-click it and choose **Edit Widget**.")
            }
        }
    }

    private func step(_ n: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(.purple))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct AboutSettings: View {
    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "Version \(short) (\(build))"
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("OpenBell")
                .font(.system(size: 22, weight: .semibold))
            Text(version)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
            Text("Countdowns to stock market opens and closes,\nin the menu bar, the app, and widgets.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Link("camosec.com", destination: URL(string: "https://camosec.com")!)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
