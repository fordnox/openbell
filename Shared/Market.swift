import Foundation
import SwiftUI

/// A trading venue with a regular daily session in its own time zone.
struct Market: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let timeZoneID: String
    /// Session open/close as minutes after local midnight in the market's time zone.
    let openMinute: Int
    let closeMinute: Int
    let is24x7: Bool
    /// Full-day closures, "yyyy-MM-dd" in the market's time zone.
    let holidays: Set<String>
    let colorRGB: (Double, Double, Double)

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var color: Color { Color(red: colorRGB.0, green: colorRGB.1, blue: colorRGB.2) }

    static func == (lhs: Market, rhs: Market) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Market {
    // US exchange holidays (NYSE / NASDAQ), 2026–2027.
    private static let usHolidays: Set<String> = [
        "2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03", "2026-05-25",
        "2026-06-19", "2026-07-03", "2026-09-07", "2026-11-26", "2026-12-25",
        "2027-01-01", "2027-01-18", "2027-02-15", "2027-03-26", "2027-05-31",
        "2027-06-18", "2027-07-05", "2027-09-06", "2027-11-25", "2027-12-24",
    ]

    // London Stock Exchange holidays, 2026–2027.
    private static let ukHolidays: Set<String> = [
        "2026-01-01", "2026-04-03", "2026-04-06", "2026-05-04", "2026-05-25",
        "2026-08-31", "2026-12-25", "2026-12-28",
        "2027-01-01", "2027-03-26", "2027-03-29", "2027-05-03", "2027-05-31",
        "2027-08-30", "2027-12-27", "2027-12-28",
    ]

    static let nyse = Market(
        id: "NYSE", name: "NYSE", timeZoneID: "America/New_York",
        openMinute: 9 * 60 + 30, closeMinute: 16 * 60, is24x7: false,
        holidays: usHolidays, colorRGB: (0.27, 0.60, 0.96))

    static let nasdaq = Market(
        id: "NASDAQ", name: "NASDAQ", timeZoneID: "America/New_York",
        openMinute: 9 * 60 + 30, closeMinute: 16 * 60, is24x7: false,
        holidays: usHolidays, colorRGB: (1.00, 0.64, 0.16))

    static let lse = Market(
        id: "LSE", name: "LSE", timeZoneID: "Europe/London",
        openMinute: 8 * 60, closeMinute: 16 * 60 + 30, is24x7: false,
        holidays: ukHolidays, colorRGB: (0.18, 0.84, 0.88))

    static let crypto = Market(
        id: "CRYPTO", name: "CRYPTO", timeZoneID: "UTC",
        openMinute: 0, closeMinute: 24 * 60, is24x7: true,
        holidays: [], colorRGB: (0.22, 0.80, 0.42))

    /// Order used by the list view.
    static let all: [Market] = [.nyse, .nasdaq, .lse, .crypto]
    /// Order used by the dial, outermost ring first.
    static let dialOrder: [Market] = [.crypto, .lse, .nyse, .nasdaq]
    /// Order used by the cards under the dial.
    static let cardOrder: [Market] = [.lse, .nyse, .nasdaq, .crypto]

    static func with(id: String) -> Market { all.first { $0.id == id } ?? .nyse }
}

// MARK: - Status

enum MarketPhase: Equatable, Sendable {
    case open(closesAt: Date)
    case closed(opensAt: Date)
    case alwaysOpen

    var isOpen: Bool {
        if case .closed = self { return false }
        return true
    }

    /// The next open/close transition, if any.
    var nextEvent: Date? {
        switch self {
        case .open(let d), .closed(let d): return d
        case .alwaysOpen: return nil
        }
    }

    var verb: String {
        switch self {
        case .open: return "Closes in"
        case .closed: return "Opens in"
        case .alwaysOpen: return "24/7"
        }
    }
}

extension Market {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return cal
    }

    private static func dayKey(_ date: Date, _ cal: Calendar) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func isTradingDay(_ date: Date) -> Bool {
        if is24x7 { return true }
        let cal = calendar
        if cal.isDateInWeekend(date) { return false }
        return !holidays.contains(Self.dayKey(date, cal))
    }

    /// The session (open...close) on the market-local day containing `day`, if it trades.
    func session(on day: Date) -> DateInterval? {
        let cal = calendar
        let start = cal.startOfDay(for: day)
        guard isTradingDay(start) else { return nil }
        if is24x7 { return DateInterval(start: start, duration: 86_400) }
        guard
            let open = cal.date(byAdding: .minute, value: openMinute, to: start),
            let close = cal.date(byAdding: .minute, value: closeMinute, to: start)
        else { return nil }
        return DateInterval(start: open, end: close)
    }

    /// All sessions overlapping `range`.
    func sessions(overlapping range: DateInterval) -> [DateInterval] {
        if is24x7 { return [range] }
        let cal = calendar
        var result: [DateInterval] = []
        var day = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: range.start))!
        while day <= range.end {
            if let s = session(on: day), let overlap = s.intersection(with: range), overlap.duration > 0 {
                result.append(overlap)
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    func phase(at now: Date) -> MarketPhase {
        if is24x7 { return .alwaysOpen }
        let cal = calendar
        let today = cal.startOfDay(for: now)
        if let s = session(on: today), s.start <= now, now < s.end {
            return .open(closesAt: s.end)
        }
        for offset in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  let s = session(on: day), s.start > now else { continue }
            return .closed(opensAt: s.start)
        }
        return .closed(opensAt: now.addingTimeInterval(86_400))
    }

    /// Market wall-clock time, e.g. "08:15".
    func localTimeString(at now: Date) -> String {
        let f = DateFormatter()
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: now)
    }

    /// "7h behind local", "2h 30m ahead of local", "Same as local".
    func offsetDescription(at now: Date, local: TimeZone = .current) -> String {
        let diff = timeZone.secondsFromGMT(for: now) - local.secondsFromGMT(for: now)
        if diff == 0 { return "Same as local" }
        let mins = abs(diff) / 60
        let h = mins / 60, m = mins % 60
        let amount = m == 0 ? "\(h)h" : (h == 0 ? "\(m)m" : "\(h)h \(m)m")
        return diff < 0 ? "\(amount) behind local" : "\(amount) ahead of local"
    }
}

// MARK: - Formatting

enum CountdownFormat {
    /// "01:14:04"
    static func hms(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded(.up)))
        return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }

    /// "01:14" (hours:minutes), or "2d 03h" when more than a day away.
    static func hm(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval.rounded(.down)))
        let days = s / 86_400
        if days > 0 { return String(format: "%dd %02dh", days, (s % 86_400) / 3600) }
        return String(format: "%02d:%02d", s / 3600, (s % 3600) / 60)
    }
}

extension TimeZone {
    /// "GMT+2", "GMT-5", "GMT+5:30"
    func gmtLabel(at date: Date) -> String {
        let secs = secondsFromGMT(for: date)
        let sign = secs < 0 ? "-" : "+"
        let h = abs(secs) / 3600, m = (abs(secs) % 3600) / 60
        if secs == 0 { return "GMT" }
        return m == 0 ? "GMT\(sign)\(h)" : "GMT\(sign)\(h):\(String(format: "%02d", m))"
    }
}

enum Palette {
    static let open = Color(red: 0.20, green: 0.80, blue: 0.40)
    static let closed = Color(red: 1.00, green: 0.23, blue: 0.19)
    static let card = Color.white.opacity(0.05)
    static let cardStroke = Color.white.opacity(0.09)
    static let secondary = Color.white.opacity(0.55)

    static func status(_ phase: MarketPhase) -> Color { phase.isOpen ? open : closed }
}
