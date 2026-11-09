import Foundation
import SwiftUI

/// A trading venue with a regular daily session in its own time zone.
struct Market: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let fullName: String
    let timeZoneID: String
    /// Session open/close as minutes after local midnight in the market's time zone.
    let openMinute: Int
    let closeMinute: Int
    let is24x7: Bool
    /// Full-day closures, "yyyy-MM-dd" in the market's time zone.
    let holidays: Set<String>
    let colorRGB: (Double, Double, Double)
    /// Midday break (start, end) in minutes after local midnight, for markets that close for lunch.
    var lunch: (Int, Int)? = nil

    var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }
    var color: Color { Color(red: colorRGB.0, green: colorRGB.1, blue: colorRGB.2) }

    static func == (lhs: Market, rhs: Market) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Holidays (full-day weekday closures, 2026–2027)

private enum Holidays {
    // NYSE / NASDAQ
    static let us: Set<String> = [
        "2026-01-01", "2026-01-19", "2026-02-16", "2026-04-03", "2026-05-25",
        "2026-06-19", "2026-07-03", "2026-09-07", "2026-11-26", "2026-12-25",
        "2027-01-01", "2027-01-18", "2027-02-15", "2027-03-26", "2027-05-31",
        "2027-06-18", "2027-07-05", "2027-09-06", "2027-11-25", "2027-12-24",
    ]

    // London Stock Exchange
    static let uk: Set<String> = [
        "2026-01-01", "2026-04-03", "2026-04-06", "2026-05-04", "2026-05-25",
        "2026-08-31", "2026-12-25", "2026-12-28",
        "2027-01-01", "2027-03-26", "2027-03-29", "2027-05-03", "2027-05-31",
        "2027-08-30", "2027-12-27", "2027-12-28",
    ]

    // Toronto Stock Exchange
    static let canada: Set<String> = [
        "2026-01-01", "2026-02-16", "2026-04-03", "2026-05-18", "2026-07-01",
        "2026-08-03", "2026-09-07", "2026-10-12", "2026-12-25", "2026-12-28",
        "2027-01-01", "2027-02-15", "2027-03-26", "2027-05-24", "2027-07-01",
        "2027-08-02", "2027-09-06", "2027-10-11", "2027-12-27", "2027-12-28",
    ]

    // Deutsche Börse Xetra
    static let xetra: Set<String> = [
        "2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-24",
        "2026-12-25", "2026-12-31",
        "2027-01-01", "2027-03-26", "2027-03-29", "2027-12-24", "2027-12-31",
    ]

    // Euronext
    static let euronext: Set<String> = [
        "2026-01-01", "2026-04-03", "2026-04-06", "2026-05-01", "2026-12-25",
        "2027-01-01", "2027-03-26", "2027-03-29",
    ]

    // Japan Exchange Group (Tokyo)
    static let japan: Set<String> = [
        "2026-01-01", "2026-01-02", "2026-01-12", "2026-02-11", "2026-02-23",
        "2026-03-20", "2026-04-29", "2026-05-04", "2026-05-05", "2026-05-06",
        "2026-07-20", "2026-08-11", "2026-09-21", "2026-09-22", "2026-09-23",
        "2026-10-12", "2026-11-03", "2026-11-23", "2026-12-31",
        "2027-01-01", "2027-01-11", "2027-02-11", "2027-02-23", "2027-03-22",
        "2027-04-29", "2027-05-03", "2027-05-04", "2027-05-05", "2027-07-19",
        "2027-08-11", "2027-09-20", "2027-09-23", "2027-10-11", "2027-11-03",
        "2027-11-23", "2027-12-31",
    ]

    // Shanghai Stock Exchange. 2027 dates are estimates until the State Council publishes them.
    static let china: Set<String> = [
        "2026-01-01", "2026-01-02", "2026-02-16", "2026-02-17", "2026-02-18",
        "2026-02-19", "2026-02-20", "2026-02-23", "2026-04-06", "2026-05-01",
        "2026-05-04", "2026-05-05", "2026-06-19", "2026-09-25", "2026-10-01",
        "2026-10-02", "2026-10-05", "2026-10-06", "2026-10-07",
        "2027-01-01", "2027-02-08", "2027-02-09", "2027-02-10", "2027-02-11",
        "2027-02-12", "2027-04-05", "2027-05-03", "2027-05-04", "2027-05-05",
        "2027-06-09", "2027-09-15", "2027-10-01", "2027-10-04", "2027-10-05",
        "2027-10-06", "2027-10-07",
    ]

    // Hong Kong Exchanges
    static let hongKong: Set<String> = [
        "2026-01-01", "2026-02-17", "2026-02-18", "2026-02-19", "2026-04-03",
        "2026-04-06", "2026-04-07", "2026-05-01", "2026-05-25", "2026-06-19",
        "2026-07-01", "2026-10-01", "2026-10-19", "2026-12-25",
        "2027-01-01", "2027-02-08", "2027-02-09", "2027-03-26", "2027-03-29",
        "2027-04-05", "2027-05-13", "2027-06-09", "2027-07-01", "2027-09-16",
        "2027-10-01", "2027-10-08", "2027-12-27",
    ]

    // National Stock Exchange of India. 2027 lists fixed-date holidays only until NSE publishes the calendar.
    static let india: Set<String> = [
        "2026-01-26", "2026-03-03", "2026-03-26", "2026-03-31", "2026-04-03",
        "2026-04-14", "2026-05-01", "2026-05-28", "2026-06-26", "2026-09-14",
        "2026-10-02", "2026-10-20", "2026-11-10", "2026-11-24", "2026-12-25",
        "2027-01-26", "2027-03-26", "2027-04-14",
    ]

    // Australian Securities Exchange
    static let australia: Set<String> = [
        "2026-01-01", "2026-01-26", "2026-04-03", "2026-04-06", "2026-06-08",
        "2026-12-25", "2026-12-28",
        "2027-01-01", "2027-01-26", "2027-03-26", "2027-03-29", "2027-06-14",
        "2027-12-27", "2027-12-28",
    ]
}

extension Market {
    static let nyse = Market(
        id: "NYSE", name: "NYSE", fullName: "New York Stock Exchange", timeZoneID: "America/New_York",
        openMinute: 9 * 60 + 30, closeMinute: 16 * 60, is24x7: false,
        holidays: Holidays.us, colorRGB: (0.27, 0.60, 0.96))

    static let nasdaq = Market(
        id: "NASDAQ", name: "NASDAQ", fullName: "Nasdaq", timeZoneID: "America/New_York",
        openMinute: 9 * 60 + 30, closeMinute: 16 * 60, is24x7: false,
        holidays: Holidays.us, colorRGB: (1.00, 0.64, 0.16))

    static let tsx = Market(
        id: "TSX", name: "TSX", fullName: "Toronto Stock Exchange", timeZoneID: "America/Toronto",
        openMinute: 9 * 60 + 30, closeMinute: 16 * 60, is24x7: false,
        holidays: Holidays.canada, colorRGB: (0.93, 0.42, 0.42))

    static let lse = Market(
        id: "LSE", name: "LSE", fullName: "London Stock Exchange", timeZoneID: "Europe/London",
        openMinute: 8 * 60, closeMinute: 16 * 60 + 30, is24x7: false,
        holidays: Holidays.uk, colorRGB: (0.18, 0.84, 0.88))

    static let xetra = Market(
        id: "XETRA", name: "XETRA", fullName: "Deutsche Börse Xetra", timeZoneID: "Europe/Berlin",
        openMinute: 9 * 60, closeMinute: 17 * 60 + 30, is24x7: false,
        holidays: Holidays.xetra, colorRGB: (0.98, 0.83, 0.24))

    static let euronext = Market(
        id: "EURONEXT", name: "EURONEXT", fullName: "Euronext (Paris, Amsterdam…)", timeZoneID: "Europe/Paris",
        openMinute: 9 * 60, closeMinute: 17 * 60 + 30, is24x7: false,
        holidays: Holidays.euronext, colorRGB: (0.50, 0.47, 0.98))

    static let tse = Market(
        id: "TSE", name: "TSE", fullName: "Tokyo Stock Exchange", timeZoneID: "Asia/Tokyo",
        openMinute: 9 * 60, closeMinute: 15 * 60 + 30, is24x7: false,
        holidays: Holidays.japan, colorRGB: (0.96, 0.36, 0.55),
        lunch: (11 * 60 + 30, 12 * 60 + 30))

    static let sse = Market(
        id: "SSE", name: "SSE", fullName: "Shanghai Stock Exchange", timeZoneID: "Asia/Shanghai",
        openMinute: 9 * 60 + 30, closeMinute: 15 * 60, is24x7: false,
        holidays: Holidays.china, colorRGB: (1.00, 0.47, 0.30),
        lunch: (11 * 60 + 30, 13 * 60))

    static let hkex = Market(
        id: "HKEX", name: "HKEX", fullName: "Hong Kong Stock Exchange", timeZoneID: "Asia/Hong_Kong",
        openMinute: 9 * 60 + 30, closeMinute: 16 * 60, is24x7: false,
        holidays: Holidays.hongKong, colorRGB: (0.84, 0.40, 0.88),
        lunch: (12 * 60, 13 * 60))

    static let nse = Market(
        id: "NSE", name: "NSE", fullName: "National Stock Exchange of India", timeZoneID: "Asia/Kolkata",
        openMinute: 9 * 60 + 15, closeMinute: 15 * 60 + 30, is24x7: false,
        holidays: Holidays.india, colorRGB: (0.36, 0.78, 0.66))

    static let asx = Market(
        id: "ASX", name: "ASX", fullName: "Australian Securities Exchange", timeZoneID: "Australia/Sydney",
        openMinute: 10 * 60, closeMinute: 16 * 60, is24x7: false,
        holidays: Holidays.australia, colorRGB: (0.80, 0.62, 0.42))

    static let crypto = Market(
        id: "CRYPTO", name: "CRYPTO", fullName: "Crypto (24/7)", timeZoneID: "UTC",
        openMinute: 0, closeMinute: 24 * 60, is24x7: true,
        holidays: [], colorRGB: (0.22, 0.80, 0.42))

    /// Order used by the list view and settings.
    static let all: [Market] = [.nyse, .nasdaq, .tsx, .lse, .xetra, .euronext, .tse, .sse, .hkex, .nse, .asx, .crypto]
    /// Stock markets in the order their sessions start through the (UTC) day.
    private static let byOpening: [Market] = [.asx, .tse, .sse, .hkex, .nse, .xetra, .euronext, .lse, .nyse, .nasdaq, .tsx]
    /// Order used by the dial, outermost ring first.
    static let dialOrder: [Market] = [.crypto] + byOpening
    /// Order used by the cards under the dial.
    static let cardOrder: [Market] = byOpening + [.crypto]

    /// Markets shown until the user picks their own.
    static let defaultEnabledIDs: Set<String> = ["NYSE", "NASDAQ", "LSE", "XETRA", "TSE"]

    static func with(id: String) -> Market { all.first { $0.id == id } ?? .nyse }

    /// Decodes the comma-separated id list stored in settings.
    static func enabledIDs(from stored: String) -> Set<String> {
        let ids = Set(stored.split(separator: ",").map(String.init)).intersection(all.map(\.id))
        return ids.isEmpty ? defaultEnabledIDs : ids
    }

    static func encode(enabledIDs: Set<String>) -> String {
        all.map(\.id).filter(enabledIDs.contains).joined(separator: ",")
    }
}

extension Array where Element == Market {
    func enabled(_ ids: Set<String>) -> [Market] { filter { ids.contains($0.id) } }
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

    /// Spoken status, e.g. "Open, closes in 1 hour, 14 minutes".
    func accessibilityDescription(now: Date) -> String {
        let f = DateComponentsFormatter()
        f.allowedUnits = [.day, .hour, .minute]
        f.unitsStyle = .full
        f.maximumUnitCount = 2
        let wait = nextEvent.flatMap { f.string(from: max(60, $0.timeIntervalSince(now))) } ?? ""
        switch self {
        case .open: return "Open, closes in \(wait)"
        case .closed: return "Closed, opens in \(wait)"
        case .alwaysOpen: return "Open 24/7"
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

    /// The trading periods on the market-local day containing `day`: one, or two around a lunch break.
    func sessions(on day: Date) -> [DateInterval] {
        let cal = calendar
        let start = cal.startOfDay(for: day)
        guard isTradingDay(start) else { return [] }
        if is24x7 { return [DateInterval(start: start, duration: 86_400)] }
        let spans = lunch.map { [(openMinute, $0.0), ($0.1, closeMinute)] } ?? [(openMinute, closeMinute)]
        return spans.compactMap { open, close in
            guard let o = cal.date(byAdding: .minute, value: open, to: start),
                  let c = cal.date(byAdding: .minute, value: close, to: start) else { return nil }
            return DateInterval(start: o, end: c)
        }
    }

    /// All sessions overlapping `range`.
    func sessions(overlapping range: DateInterval) -> [DateInterval] {
        if is24x7 { return [range] }
        let cal = calendar
        var result: [DateInterval] = []
        var day = cal.date(byAdding: .day, value: -1, to: cal.startOfDay(for: range.start))!
        while day <= range.end {
            for s in sessions(on: day) {
                if let overlap = s.intersection(with: range), overlap.duration > 0 { result.append(overlap) }
            }
            day = cal.date(byAdding: .day, value: 1, to: day)!
        }
        return result
    }

    /// Lunch breaks count as closed: the countdown runs to the break, then to the reopen.
    func phase(at now: Date) -> MarketPhase {
        if is24x7 { return .alwaysOpen }
        let cal = calendar
        let today = cal.startOfDay(for: now)
        if let s = sessions(on: today).first(where: { $0.start <= now && now < $0.end }) {
            return .open(closesAt: s.end)
        }
        for offset in 0..<30 {
            guard let day = cal.date(byAdding: .day, value: offset, to: today),
                  let s = sessions(on: day).first(where: { $0.start > now }) else { continue }
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
