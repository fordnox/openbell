import SwiftUI

struct AppearanceSettingsPane: View {
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
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
    }
}
