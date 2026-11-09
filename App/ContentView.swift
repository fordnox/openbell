import SwiftUI

enum DisplayMode: String, CaseIterable, Identifiable {
    case list = "List", dial = "Dial"
    var id: String { rawValue }
}

struct ContentView: View {
    var compact = false
    @EnvironmentObject private var clock: Clock
    @AppStorage("displayMode") private var mode: DisplayMode = .list
    @AppStorage("menuBarMarket") private var menuBarMarketID = Market.nyse.id

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Markets")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                SegmentedToggle(selection: $mode)
                    .frame(width: 200)
            }

            Group {
                switch mode {
                case .list: MarketListView(now: clock.now)
                case .dial: SessionsDialCard(now: clock.now)
                }
            }
            .transition(.opacity)

            HStack {
                Menu {
                    Picker("Menu bar market", selection: $menuBarMarketID) {
                        ForEach(Market.all) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.inline)
                } label: {
                    Text("Menu bar: \(Market.with(id: menuBarMarketID).name)")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .foregroundStyle(Palette.secondary)

                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .buttonStyle(.plain)
                    .foregroundStyle(Palette.secondary)
                    .keyboardShortcut("q")
            }
            .font(.system(size: 14))
        }
        .padding(compact ? 18 : 24)
        .padding(.top, compact ? 0 : 4)
        .background(Color(white: 0.16))
        .animation(.easeInOut(duration: 0.2), value: mode)
    }
}

/// Pill-style two-option switch matching the design.
struct SegmentedToggle: View {
    @Binding var selection: DisplayMode
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 0) {
            ForEach(DisplayMode.allCases) { option in
                Button {
                    selection = option
                } label: {
                    Text(option.rawValue)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == option ? .white : .white.opacity(0.6))
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .background {
                            if selection == option {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white.opacity(0.28))
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.18)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Palette.cardStroke))
    }
}

// MARK: - List

struct MarketListView: View {
    let now: Date

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(Market.all.enumerated()), id: \.element.id) { index, market in
                MarketRow(market: market, now: now)
                if index < Market.all.count - 1 {
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.cardStroke))
    }
}

struct MarketRow: View {
    let market: Market
    let now: Date

    var body: some View {
        let phase = market.phase(at: now)
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 6) {
                Text(market.name)
                    .font(.system(size: 17, weight: .semibold))
                Text(market.offsetDescription(at: now))
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.secondary)
                HStack(spacing: 8) {
                    Text(phase.verb).foregroundStyle(Palette.secondary)
                    CountdownText(phase: phase, now: now)
                        .foregroundStyle(.white.opacity(0.9))
                }
                .font(.system(size: 14, design: .monospaced))
            }
            Spacer()
            Text(market.localTimeString(at: now))
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.9))
            StatusDot(phase: phase, size: 14)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Dial

struct SessionsDialCard: View {
    let now: Date

    var body: some View {
        VStack(spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sessions")
                    .font(.system(size: 20, weight: .semibold))
                Text(TimeZone.current.gmtLabel(at: now))
                    .font(.system(size: 16))
                    .foregroundStyle(Palette.secondary)
                Spacer()
                Text(now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                    .font(.system(size: 16, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.75))
            }

            DialView(now: now)
                .frame(maxWidth: 340)
                .padding(.vertical, 4)

            HStack(spacing: 10) {
                ForEach(Market.cardOrder) { m in
                    MarketCard(market: m, now: now)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Palette.card))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.cardStroke))
    }
}
