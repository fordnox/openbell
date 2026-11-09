import SwiftUI

struct MarketsSettingsPane: View {
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
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
