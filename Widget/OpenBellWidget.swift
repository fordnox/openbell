import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Configuration

enum MarketChoice: String, AppEnum {
    case nyse = "NYSE", nasdaq = "NASDAQ", tsx = "TSX", lse = "LSE", xetra = "XETRA", euronext = "EURONEXT"
    case tse = "TSE", sse = "SSE", hkex = "HKEX", nse = "NSE", asx = "ASX", crypto = "CRYPTO"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Market"
    static var caseDisplayRepresentations: [MarketChoice: DisplayRepresentation] = [
        .nyse: "NYSE", .nasdaq: "NASDAQ", .tsx: "TSX (Toronto)", .lse: "LSE (London)",
        .xetra: "Xetra (Frankfurt)", .euronext: "Euronext", .tse: "TSE (Tokyo)", .sse: "SSE (Shanghai)",
        .hkex: "HKEX (Hong Kong)", .nse: "NSE (India)", .asx: "ASX (Sydney)", .crypto: "Crypto",
    ]

    var market: Market { Market.with(id: rawValue) }
}

struct SelectMarketIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Market"
    static var description = IntentDescription("Choose which market to count down to.")

    @Parameter(title: "Market", default: .nyse)
    var market: MarketChoice
}

// MARK: - Timeline

struct MarketEntry: TimelineEntry {
    let date: Date
    let market: Market
}

struct MarketProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MarketEntry {
        MarketEntry(date: .now, market: .nyse)
    }

    func snapshot(for configuration: SelectMarketIntent, in context: Context) async -> MarketEntry {
        MarketEntry(date: .now, market: configuration.market.market)
    }

    func timeline(for configuration: SelectMarketIntent, in context: Context) async -> Timeline<MarketEntry> {
        minuteTimeline(market: configuration.market.market)
    }
}

/// For widgets that show every market and need no configuration.
struct AllMarketsProvider: TimelineProvider {
    func placeholder(in context: Context) -> MarketEntry { MarketEntry(date: .now, market: .nyse) }

    func getSnapshot(in context: Context, completion: @escaping (MarketEntry) -> Void) {
        completion(MarketEntry(date: .now, market: .nyse))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MarketEntry>) -> Void) {
        completion(minuteTimeline(market: .nyse))
    }
}

/// One entry per minute for two hours: keeps the dial hand, clocks and open/closed
/// states fresh. Countdown text ticks on its own between entries.
func minuteTimeline(market: Market) -> Timeline<MarketEntry> {
    let now = Date()
    let minuteStart = Date(timeIntervalSinceReferenceDate: (now.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
    let entries = (0..<120).map { i in
        MarketEntry(date: i == 0 ? now : minuteStart.addingTimeInterval(Double(i) * 60), market: market)
    }
    return Timeline(entries: entries, policy: .atEnd)
}

// MARK: - Views

struct WidgetBackground: View {
    var body: some View {
        LinearGradient(colors: [Color(white: 0.19), Color(white: 0.12)], startPoint: .top, endPoint: .bottom)
    }
}

/// Small: one market with a big live countdown.
struct SingleMarketView: View {
    let entry: MarketEntry

    var body: some View {
        let market = entry.market
        let phase = market.phase(at: entry.date)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                MarketBadge(market: market, size: 12)
                Text(market.name)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                StatusDot(phase: phase, size: 8)
            }
            Spacer(minLength: 0)
            Text(phase.isOpen ? (market.is24x7 ? "Always open" : "Open") : "Closed")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.status(phase))
            Text(phase.verb)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(Palette.secondary)
            if phase.nextEvent != nil {
                CountdownText(phase: phase, now: entry.date, live: true)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text("\(market.localTimeString(at: entry.date)) · \(market.offsetDescription(at: entry.date))")
                .font(.system(size: 10))
                .foregroundStyle(Palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(.white)
    }
}

/// Medium: all markets as compact rows.
struct MarketListWidgetView: View {
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            let markets = Market.all.enabled(Market.defaultEnabledIDs)
            ForEach(Array(markets.enumerated()), id: \.element.id) { index, market in
                let phase = market.phase(at: date)
                HStack(spacing: 8) {
                    MarketBadge(market: market, size: 10)
                    Text(market.name)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 66, alignment: .leading)
                    Text(phase.verb)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Palette.secondary)
                    CountdownText(phase: phase, now: date, live: true)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(market.localTimeString(at: date))
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.85))
                    StatusDot(phase: phase, size: 8)
                }
                .frame(maxHeight: .infinity)
                if index < markets.count - 1 {
                    Divider().overlay(Color.white.opacity(0.06))
                }
            }
        }
        .foregroundStyle(.white)
    }
}

/// Large: the session dial with cards underneath.
struct DialWidgetView: View {
    let date: Date

    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Sessions").font(.system(size: 15, weight: .semibold))
                Text(TimeZone.current.gmtLabel(at: date))
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.secondary)
                Spacer()
            }
            DialView(now: date, markets: Market.dialOrder.enabled(Market.defaultEnabledIDs))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            if SharedSettings.showDialCards {
                MarketCardGrid(markets: Market.cardOrder.enabled(Market.defaultEnabledIDs),
                               now: date, live: true, compact: true, spacing: 6)
            }
        }
        .foregroundStyle(.white)
    }
}

// MARK: - Widgets

struct MarketCountdownWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "MarketCountdown", intent: SelectMarketIntent.self, provider: MarketProvider()) { entry in
            SingleMarketView(entry: entry)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Market Countdown")
        .description("Time until a market opens or closes.")
        .supportedFamilies([.systemSmall])
    }
}

struct MarketsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Markets", provider: AllMarketsProvider()) { entry in
            MarketListWidgetView(date: entry.date)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Markets")
        .description("Open/closed status and countdowns for all markets.")
        .supportedFamilies([.systemMedium])
    }
}

struct SessionsDialWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SharedSettings.dialWidgetKind, provider: AllMarketsProvider()) { entry in
            DialWidgetView(date: entry.date)
                .containerBackground(for: .widget) { WidgetBackground() }
        }
        .configurationDisplayName("Sessions Dial")
        .description("A 24-hour dial of today's trading sessions.")
        .supportedFamilies([.systemLarge])
    }
}

@main
struct OpenBellWidgetBundle: WidgetBundle {
    var body: some Widget {
        MarketCountdownWidget()
        MarketsWidget()
        SessionsDialWidget()
    }
}
