// Draws the app icon (a gold varsity-letter G on navy) and writes an .iconset folder.
// Usage: swift scripts/make-icon.swift <out.iconset>   (scripts/make-icon.sh wraps this)
import AppKit

let outDir = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

/// A chamfered block-letter G on a 10 x 12 unit grid (y up).
func letterG(unit u: CGFloat, origin o: CGPoint) -> CGPath {
    let points: [(CGFloat, CGFloat)] = [
        (1.5, 12), (8.5, 12), (10, 10.5), (10, 8.6), (7.4, 8.6), (7.4, 8.8),
        (6.8, 9.4), (3.2, 9.4), (2.6, 8.8), (2.6, 3.2), (3.2, 2.6), (6.8, 2.6),
        (7.4, 3.2), (7.4, 4.6), (5.4, 4.6), (5.4, 6.8), (10, 6.8), (10, 1.5),
        (8.5, 0), (1.5, 0), (0, 1.5), (0, 10.5),
    ]
    let path = CGMutablePath()
    for (i, p) in points.enumerated() {
        let point = CGPoint(x: o.x + p.0 * u, y: o.y + p.1 * u)
        if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    path.closeSubpath()
    return path
}

func render(pixels: Int) -> Data {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: rep)!
    let g = context.cgContext
    g.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    // Standard macOS icon grid: an 824pt rounded square centered on a 1024pt canvas.
    let plate = CGPath(
        roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
        cornerWidth: 185, cornerHeight: 185, transform: nil)

    g.saveGState()
    g.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: rgb(0, 0, 0, 0.4))
    g.addPath(plate)
    g.setFillColor(rgb(0.04, 0.08, 0.20))
    g.fillPath()
    g.restoreGState()

    g.saveGState()
    g.addPath(plate)
    g.clip()
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let navy = CGGradient(
        colorsSpace: space,
        colors: [rgb(0.13, 0.23, 0.52), rgb(0.03, 0.06, 0.17)] as CFArray,
        locations: [0, 1])!
    g.drawLinearGradient(
        navy, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    // Soft glow behind the letter.
    let glow = CGGradient(
        colorsSpace: space,
        colors: [rgb(0.35, 0.50, 0.95, 0.35), rgb(0.35, 0.50, 0.95, 0)] as CFArray,
        locations: [0, 1])!
    g.drawRadialGradient(
        glow, startCenter: CGPoint(x: 512, y: 560), startRadius: 0,
        endCenter: CGPoint(x: 512, y: 560), endRadius: 430, options: [])
    g.restoreGState()

    let unit: CGFloat = 43
    let letter = letterG(unit: unit, origin: CGPoint(x: 512 - 5 * unit, y: 512 - 6 * unit))
    g.setLineJoin(.miter)

    // Letterman patch: cream outline, navy gap, gold letter.
    g.saveGState()
    g.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: rgb(0, 0, 0, 0.45))
    g.addPath(letter)
    g.setStrokeColor(rgb(0.98, 0.95, 0.86))
    g.setLineWidth(60)
    g.strokePath()
    g.restoreGState()

    g.addPath(letter)
    g.setStrokeColor(rgb(0.04, 0.08, 0.20))
    g.setLineWidth(32)
    g.strokePath()

    g.saveGState()
    g.addPath(letter)
    g.clip()
    let gold = CGGradient(
        colorsSpace: space,
        colors: [rgb(1.0, 0.84, 0.30), rgb(0.93, 0.62, 0.08)] as CFArray,
        locations: [0, 1])!
    g.drawLinearGradient(
        gold, start: CGPoint(x: 512, y: 780), end: CGPoint(x: 512, y: 250), options: [])
    g.restoreGState()

    context.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    try render(pixels: size).write(to: outDir.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(pixels: size * 2)
        .write(to: outDir.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
