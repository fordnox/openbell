import SwiftUI
import WidgetKit

struct AppearanceSettingsPane: View {
    @AppStorage(SettingsKey.displayMode) private var mode: DisplayMode = .list
    @AppStorage(SharedSettings.showDialCardsKey, store: SharedSettings.store) private var showDialCards = true

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

            Section {
                Toggle("Show market cards under the dial", isOn: $showDialCards)
                    .onChange(of: showDialCards) { _, _ in
                        WidgetCenter.shared.reloadTimelines(ofKind: SharedSettings.dialWidgetKind)
                    }
            } header: {
                Text("Dial")
            } footer: {
                Text("Also applies to the large Sessions Dial widget.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
