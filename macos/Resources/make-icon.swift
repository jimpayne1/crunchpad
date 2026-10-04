// SPDX-License-Identifier: GPL-2.0-or-later
//
// Renders the app icon into an .iconset directory (argv[1]); build.sh turns it
// into AppIcon.icns with iconutil. Kept as code so the icon is reproducible.

import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.removeItem(at: out)
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                               isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)

    // macOS icon grid: 824/1024 body, ~185/1024 corner radius.
    let inset = s * 100 / 1024
    let body = NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let path = NSBezierPath(roundedRect: body, xRadius: s * 185 / 1024, yRadius: s * 185 / 1024)

    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.shadowBlurRadius = s * 0.02
    shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)
    shadow.set()
    NSColor.black.setFill()
    path.fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGradient(colors: [
        NSColor(srgbRed: 0.98, green: 0.55, blue: 0.20, alpha: 1),
        NSColor(srgbRed: 0.90, green: 0.25, blue: 0.30, alpha: 1),
    ])!.draw(in: path, angle: -90)

    // Display slab.
    let slab = NSRect(x: body.minX + body.width * 0.12, y: body.minY + body.height * 0.52,
                      width: body.width * 0.76, height: body.height * 0.30)
    NSColor.black.withAlphaComponent(0.22).setFill()
    NSBezierPath(roundedRect: slab, xRadius: s * 0.04, yRadius: s * 0.04).fill()

    let mono = NSFont.monospacedSystemFont(ofSize: s * 0.15, weight: .semibold)
    let digits = NSAttributedString(string: "3.1415", attributes: [
        .font: mono, .foregroundColor: NSColor.white,
    ])
    let dSize = digits.size()
    digits.draw(at: NSPoint(x: slab.maxX - dSize.width - s * 0.04, y: slab.midY - dSize.height / 2))

    let glyph = NSAttributedString(string: "√x", attributes: [
        .font: NSFont.systemFont(ofSize: s * 0.26, weight: .bold),
        .foregroundColor: NSColor.white,
    ])
    let gSize = glyph.size()
    glyph.draw(at: NSPoint(x: body.midX - gSize.width / 2, y: body.minY + body.height * 0.10))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try render(base * scale).write(to: out.appendingPathComponent(name))
    }
}
