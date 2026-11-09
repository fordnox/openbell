import SwiftUI

struct WidgetsSettingsPane: View {
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
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .contentMargins(.top, 8, for: .scrollContent)
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
