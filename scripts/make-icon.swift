// Renders the OpenBell app icon (a stylised session dial) into an asset catalog.
// Usage: swift scripts/make-icon.swift App/Assets.xcassets/AppIcon.appiconset
import AppKit

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let S: CGFloat = 1024

func render() -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: 824pt body centered in 1024 with drop shadow.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: NSColor.black.withAlphaComponent(0.45).cgColor)
    ctx.addPath(shape); ctx.setFillColor(NSColor(white: 0.12, alpha: 1).cgColor); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                        colors: [NSColor(white: 0.24, alpha: 1).cgColor, NSColor(white: 0.09, alpha: 1).cgColor] as CFArray,
                        locations: [0, 1])!
    ctx.drawLinearGradient(bg, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])

    let c = CGPoint(x: 512, y: 512)
    // CG angles: 0 = right, counter-clockwise. Day fraction f → top-origin clockwise.
    func ang(_ f: CGFloat) -> CGFloat { .pi / 2 - f * 2 * .pi }
    func ring(_ r: CGFloat, _ w: CGFloat, _ color: NSColor, from f0: CGFloat, to f1: CGFloat, round: Bool = true) {
        ctx.setLineWidth(w); ctx.setLineCap(round ? .round : .butt)
        ctx.setStrokeColor(color.cgColor)
        ctx.addArc(center: c, radius: r, startAngle: ang(f0), endAngle: ang(f1), clockwise: true)
        ctx.strokePath()
    }
    let w: CGFloat = 52, step: CGFloat = 66
    // Tracks
    func circle(_ r: CGFloat, _ color: NSColor) {
        ctx.setLineWidth(w); ctx.setStrokeColor(color.cgColor)
        ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
    for i in 0..<4 { circle(330 - CGFloat(i) * step, NSColor(white: 1, alpha: 0.06)) }
    circle(330, NSColor(red: 0.22, green: 0.80, blue: 0.42, alpha: 1)) // crypto
    ring(330 - step, w, NSColor(red: 0.18, green: 0.84, blue: 0.88, alpha: 1), from: 0.42, to: 0.77)   // LSE
    ring(330 - 2 * step, w, NSColor(red: 0.27, green: 0.60, blue: 0.96, alpha: 1), from: 0.69, to: 0.96) // NYSE
    ring(330 - 3 * step, w, NSColor(red: 1.00, green: 0.64, blue: 0.16, alpha: 1), from: 0.69, to: 0.93) // NASDAQ

    // Center disc
    let ir: CGFloat = 330 - 3 * step - w / 2 - 14
    ctx.setFillColor(NSColor(white: 0.08, alpha: 1).cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - ir, y: c.y - ir, width: ir * 2, height: ir * 2))

    // Hand at ~15:15 with knob
    let f: CGFloat = 0.635
    let end = CGPoint(x: c.x + 372 * cos(ang(f)), y: c.y + 372 * sin(ang(f)))
    ctx.setStrokeColor(NSColor.white.cgColor); ctx.setLineWidth(14); ctx.setLineCap(.round)
    ctx.move(to: c); ctx.addLine(to: end); ctx.strokePath()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: c.x - 30, y: c.y - 30, width: 60, height: 60))
    ctx.fillEllipse(in: CGRect(x: end.x - 34, y: end.y - 34, width: 68, height: 68))
    ctx.restoreGState()

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let master = render()
let sizes: [(Int, Int)] = [(16, 1), (16, 2), (32, 1), (32, 2), (128, 1), (128, 2), (256, 1), (256, 2), (512, 1), (512, 2)]
var images: [String] = []
for (pt, scale) in sizes {
    let px = pt * scale
    let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
    let img = NSImage(size: NSSize(width: px, height: px))
    let small = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                                 samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                 bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: small)
    NSGraphicsContext.current!.imageInterpolation = .high
    master.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    _ = img
    try! small.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
    images.append("""
        { "idiom" : "mac", "size" : "\(pt)x\(pt)", "scale" : "\(scale)x", "filename" : "\(name)" }
    """)
}
let contents = "{\n  \"images\" : [\n\(images.joined(separator: ",\n"))\n  ],\n  \"info\" : { \"version\" : 1, \"author\" : \"xcode\" }\n}\n"
try! contents.write(toFile: "\(out)/Contents.json", atomically: true, encoding: .utf8)
print("Wrote \(sizes.count) icons to \(out)")
