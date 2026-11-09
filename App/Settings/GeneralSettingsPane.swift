import SwiftUI

struct GeneralSettingsPane: View {
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
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
