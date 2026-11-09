import SwiftUI

/// 24-hour session dial: 00 at top, clockwise, in the viewer's local time.
/// Each market gets a concentric ring showing its trading sessions; a hand marks "now".
struct DialView: View {
    let now: Date
    var markets: [Market] = Market.dialOrder
    var showsCenterTime = true
    var showsLabels = true

    var body: some View {
        Canvas { ctx, size in
            draw(ctx: ctx, size: size)
        }
        .overlay {
            if showsCenterTime { centerLabel }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: Geometry

    private struct Layout {
        let center: CGPoint
        let outer: CGFloat      // radius of the outermost ring's centerline
        let ringWidth: CGFloat
        let ringGap: CGFloat
        let inner: CGFloat      // radius of the center disc

        func radius(ring i: Int) -> CGFloat { outer - CGFloat(i) * (ringWidth + ringGap) }
    }

    private func layout(for size: CGSize, ringCount: Int) -> Layout {
        let side = min(size.width, size.height)
        let n = CGFloat(max(ringCount, 1))
        // Outer edge of the rings leaves room for the ticks and hour labels;
        // the center disc never gets smaller than what the center time needs.
        let edge = side * 0.4055
        let minInner = side * 0.147
        let gapRatio: CGFloat = 0.207
        // Rings + gaps fill the band between the two: n widths, n + 1 gaps.
        let ringWidth = min(side * 0.0513, (edge - minInner) / (n + gapRatio * (n + 1)))
        let ringGap = ringWidth * gapRatio
        let outer = edge - ringWidth / 2
        let lastRing = outer - (n - 1) * (ringWidth + ringGap)
        return Layout(center: CGPoint(x: size.width / 2, y: size.height / 2),
                      outer: outer, ringWidth: ringWidth, ringGap: ringGap,
                      inner: lastRing - ringWidth / 2 - ringGap * 2)
    }

    /// Fraction of the local day (0..<1) for a date.
    private func dayFraction(_ date: Date) -> Double {
        let cal = Calendar.current
        let c = cal.dateComponents([.hour, .minute, .second], from: date)
        return (Double(c.hour ?? 0) * 3600 + Double(c.minute ?? 0) * 60 + Double(c.second ?? 0)) / 86_400
    }

    /// Screen angle for a day fraction; 0 → top, increasing clockwise.
    private func angle(_ fraction: Double) -> Angle { .degrees(fraction * 360 - 90) }

    private func point(_ l: Layout, radius: CGFloat, angle: Angle) -> CGPoint {
        CGPoint(x: l.center.x + radius * cos(angle.radians), y: l.center.y + radius * sin(angle.radians))
    }

    private func arc(_ l: Layout, radius: CGFloat, from start: Double, span: Double) -> Path {
        Path { p in
            let steps = max(2, Int(span * 360))
            for i in 0...steps {
                let f = start + span * Double(i) / Double(steps)
                let pt = point(l, radius: radius, angle: angle(f))
                i == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
        }
    }

    // MARK: Drawing

    private func draw(ctx: GraphicsContext, size: CGSize) {
        let l = layout(for: size, ringCount: markets.count)
        let side = min(size.width, size.height)

        // Backplate with subtle concentric grooves.
        let plateR = l.outer + l.ringWidth / 2 + side * 0.012
        ctx.fill(Path(ellipseIn: CGRect(x: l.center.x - plateR, y: l.center.y - plateR,
                                        width: plateR * 2, height: plateR * 2)),
                 with: .radialGradient(Gradient(colors: [Color(white: 0.10), Color(white: 0.17)]),
                                       center: l.center, startRadius: 0, endRadius: plateR))
        var r = l.inner
        while r < plateR {
            ctx.stroke(Path(ellipseIn: CGRect(x: l.center.x - r, y: l.center.y - r, width: r * 2, height: r * 2)),
                       with: .color(.white.opacity(0.035)), lineWidth: 1)
            r += side * 0.022
        }

        // Hour ticks and labels around the outside.
        let tickIn = plateR + side * 0.008
        for h in 0..<24 {
            let a = angle(Double(h) / 24)
            let major = h % 6 == 0
            let len = side * (major ? 0.0 : 0.018)
            if !major {
                var tick = Path()
                tick.move(to: point(l, radius: tickIn, angle: a))
                tick.addLine(to: point(l, radius: tickIn + len, angle: a))
                ctx.stroke(tick, with: .color(.white.opacity(0.18)), lineWidth: max(1, side * 0.003))
            } else {
                let label = Text(String(format: "%02d", h))
                    .font(.system(size: side * 0.042, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.45))
                ctx.draw(label, at: point(l, radius: plateR + side * 0.038, angle: a))
            }
        }

        // Sessions within ±12h of now, so the window seam sits opposite the hand.
        let window = DateInterval(start: now.addingTimeInterval(-43_200), duration: 86_400)
        let nowF = dayFraction(now)

        for (i, market) in markets.enumerated() {
            let radius = l.radius(ring: i)
            let full = Path(ellipseIn: CGRect(x: l.center.x - radius, y: l.center.y - radius,
                                              width: radius * 2, height: radius * 2))
            ctx.stroke(full, with: .color(.white.opacity(0.05)), lineWidth: l.ringWidth)

            let style = StrokeStyle(lineWidth: l.ringWidth, lineCap: market.is24x7 ? .butt : .round)
            if market.is24x7 {
                ctx.stroke(full, with: .linearGradient(
                    Gradient(colors: [market.color.opacity(0.95), market.color.opacity(0.75)]),
                    startPoint: CGPoint(x: l.center.x, y: l.center.y - radius),
                    endPoint: CGPoint(x: l.center.x, y: l.center.y + radius)), style: style)
            } else {
                for s in market.sessions(overlapping: window) {
                    let path = arc(l, radius: radius, from: dayFraction(s.start), span: s.duration / 86_400)
                    var glow = ctx
                    glow.addFilter(.blur(radius: side * 0.01))
                    glow.stroke(path, with: .color(market.color.opacity(0.35)), style: style)
                    ctx.stroke(path, with: .color(market.color), style: style)
                }
            }

            if showsLabels { drawCurvedLabel(ctx: ctx, l: l, radius: radius, text: market.name, side: side) }
        }

        // Center disc.
        let inner = l.inner
        ctx.fill(Path(ellipseIn: CGRect(x: l.center.x - inner, y: l.center.y - inner, width: inner * 2, height: inner * 2)),
                 with: .radialGradient(Gradient(colors: [Color(white: 0.07), Color(white: 0.13)]),
                                       center: l.center, startRadius: 0, endRadius: inner))
        ctx.stroke(Path(ellipseIn: CGRect(x: l.center.x - inner, y: l.center.y - inner, width: inner * 2, height: inner * 2)),
                   with: .color(.white.opacity(0.08)), lineWidth: 1)

        // Hand: from the center disc's edge out past the outer ring.
        let a = angle(nowF)
        let handEnd = l.outer + l.ringWidth / 2 + side * 0.004
        var hand = Path()
        hand.move(to: point(l, radius: inner, angle: a))
        hand.addLine(to: point(l, radius: handEnd, angle: a))
        ctx.stroke(hand, with: .color(.white.opacity(0.75)), lineWidth: max(1, side * 0.004))

        let dotR = l.ringWidth * 0.2
        for (i, market) in markets.enumerated() {
            let c = point(l, radius: l.radius(ring: i), angle: a)
            let color = Palette.status(market.phase(at: now))
            let rect = CGRect(x: c.x - dotR, y: c.y - dotR, width: dotR * 2, height: dotR * 2)
            ctx.fill(Path(ellipseIn: rect), with: .color(color))
            ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.85)), lineWidth: max(0.5, side * 0.002))
        }
        let knobR = max(l.ringWidth, side * 0.04) * 0.32
        let k = point(l, radius: handEnd, angle: a)
        ctx.fill(Path(ellipseIn: CGRect(x: k.x - knobR, y: k.y - knobR, width: knobR * 2, height: knobR * 2)),
                 with: .radialGradient(Gradient(colors: [.white, Color(white: 0.55)]),
                                       center: CGPoint(x: k.x - knobR * 0.3, y: k.y - knobR * 0.3),
                                       startRadius: 0, endRadius: knobR * 1.4))
    }

    /// Letters spaced along the top of a ring, reading left to right.
    private func drawCurvedLabel(ctx: GraphicsContext, l: Layout, radius: CGFloat, text: String, side: CGFloat) {
        let fontSize = l.ringWidth * 0.55
        guard fontSize >= 5 else { return } // too many rings to label legibly
        let letterAngle = Double(fontSize * 1.05 / radius) // radians per glyph
        let chars = Array(text)
        let total = letterAngle * Double(chars.count - 1)
        for (i, ch) in chars.enumerated() {
            let theta = -Double.pi / 2 - total / 2 + letterAngle * Double(i)
            let p = CGPoint(x: l.center.x + radius * cos(theta), y: l.center.y + radius * sin(theta))
            var c = ctx
            c.translateBy(x: p.x, y: p.y)
            c.rotate(by: .radians(theta + .pi / 2))
            c.draw(Text(String(ch))
                    .font(.system(size: fontSize, weight: .bold, design: .rounded))
                    .foregroundColor(.white.opacity(0.55)),
                   at: .zero)
        }
    }

    private var centerLabel: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            VStack(spacing: side * 0.005) {
                Text("SESSIONS")
                    .font(.system(size: side * 0.03, weight: .semibold))
                    .kerning(side * 0.008)
                    .foregroundStyle(.white.opacity(0.6))
                Text(now, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                    .font(.system(size: side * 0.09, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
}

// MARK: - Small shared pieces

struct StatusDot: View {
    let phase: MarketPhase
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(Palette.status(phase))
            .frame(width: size, height: size)
            .padding(size * 0.2)
            .background(Circle().fill(Color.black.opacity(0.35)))
    }
}

struct MarketBadge: View {
    let market: Market
    var size: CGFloat = 14

    var body: some View {
        Circle()
            .strokeBorder(market.color, lineWidth: size * 0.2)
            .background(Circle().fill(market.color.opacity(0.35)))
            .frame(width: size, height: size)
            .padding(size * 0.15)
            .background(Circle().fill(market.color.opacity(0.18)))
    }
}

/// Countdown to the market's next open/close.
/// `live` = true uses SwiftUI's self-updating timer text (for widgets);
/// otherwise renders a fixed HH:MM:SS string for the given `now`.
struct CountdownText: View {
    let phase: MarketPhase
    let now: Date
    var live = false

    var body: some View {
        if let target = phase.nextEvent {
            if live {
                Text(timerInterval: now...max(now, target), countsDown: true)
                    .monospacedDigit()
            } else {
                Text(CountdownFormat.hms(target.timeIntervalSince(now)))
                    .monospacedDigit()
            }
        } else {
            Text("")
        }
    }
}

/// Cards in evenly filled rows of at most four (5 → 3+2, 6 → 3+3, 7 → 4+3).
struct MarketCardGrid: View {
    let markets: [Market]
    let now: Date
    var live = false
    var compact = false
    var spacing: CGFloat = 10

    var body: some View {
        let rows = Int((Double(markets.count) / 4).rounded(.up))
        let perRow = max(1, Int((Double(markets.count) / Double(max(rows, 1))).rounded(.up)))
        VStack(spacing: spacing) {
            ForEach(Array(stride(from: 0, to: markets.count, by: perRow)), id: \.self) { start in
                HStack(spacing: spacing) {
                    ForEach(markets[start..<Swift.min(start + perRow, markets.count)]) { m in
                        MarketCard(market: m, now: now, live: live, compact: compact)
                    }
                    // Keep a short last row's cards the same width as the rows above.
                    ForEach(0..<(perRow - Swift.min(perRow, markets.count - start)), id: \.self) { _ in
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                    }
                }
            }
        }
    }
}

/// The compact card shown under the dial.
struct MarketCard: View {
    let market: Market
    let now: Date
    var live = false
    /// Narrow layout for widgets: no badge, smaller type, name tinted with market color.
    var compact = false

    var body: some View {
        let phase = market.phase(at: now)
        VStack(spacing: compact ? 4 : 6) {
            HStack(spacing: compact ? 4 : 5) {
                if !compact { MarketBadge(market: market, size: 12) }
                Text(market.name)
                    .font(.system(size: compact ? 11 : 13, weight: .semibold))
                    .foregroundStyle(compact ? market.color : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .truncationMode(.tail)
                    .layoutPriority(-1)
                StatusDot(phase: phase, size: 7)
            }
            Text(phase.verb)
                .font(.system(size: compact ? 10 : 11, design: .monospaced))
                .foregroundStyle(Palette.secondary)
            CountdownText(phase: phase, now: now, live: live)
                .font(.system(size: compact ? 11 : 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: 14)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 8 : 10)
        .padding(.horizontal, compact ? 4 : 6)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Palette.cardStroke))
    }
}
