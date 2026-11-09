import AppKit
import Combine
import SwiftUI
import WidgetKit

/// Ticks once per second so the window and menu bar stay live.
@MainActor
final class Clock: ObservableObject {
    @Published var now = Date()
    private var timer: AnyCancellable?

    init() {
        timer = Timer.publish(every: 1, tolerance: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }
    }
}

@main
struct MarketHoursApp: App {
    @StateObject private var clock = Clock()
    @AppStorage("menuBarMarket") private var menuBarMarketID = Market.nyse.id

    var body: some Scene {
        WindowGroup("MarketHours", id: "main") {
            ContentView()
                .environmentObject(clock)
                .frame(width: 480)
                .preferredColorScheme(.dark)
                .onAppear { WidgetCenter.shared.reloadAllTimelines() }
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 480, height: 640)

        MenuBarExtra {
            ContentView(compact: true)
                .environmentObject(clock)
                .frame(width: 420)
                .preferredColorScheme(.dark)
        } label: {
            MenuBarLabel(market: Market.with(id: menuBarMarketID), now: clock.now)
        }
        .menuBarExtraStyle(.window)
    }
}

/// "● NYSE 01:14" — red/green dot plus hours:minutes to the next open/close.
struct MenuBarLabel: View {
    let market: Market
    let now: Date

    var body: some View {
        let phase = market.phase(at: now)
        HStack(spacing: 4) {
            Image(nsImage: Self.dot(Palette.status(phase)))
            if let next = phase.nextEvent {
                Text("\(market.name) \(CountdownFormat.hm(next.timeIntervalSince(now)))")
                    .monospacedDigit()
            } else {
                Text("\(market.name) 24/7")
            }
        }
    }

    /// Menu bar images are template-tinted by default; build a non-template colored dot.
    static func dot(_ color: Color) -> NSImage {
        let size = NSSize(width: 9, height: 9)
        let image = NSImage(size: size, flipped: false) { rect in
            NSColor(color).setFill()
            NSBezierPath(ovalIn: rect).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
