// Renders the Captioner app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let canvas: CGFloat = 1024

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// Four-point "sparkle" star centered at `c`.
func sparkle(at c: CGPoint, radius r: CGFloat, waist: CGFloat = 0.18) -> NSBezierPath {
    let p = NSBezierPath()
    let w = r * waist
    p.move(to: CGPoint(x: c.x, y: c.y + r))
    p.curve(to: CGPoint(x: c.x + r, y: c.y), controlPoint1: CGPoint(x: c.x + w, y: c.y + w), controlPoint2: CGPoint(x: c.x + w, y: c.y + w))
    p.curve(to: CGPoint(x: c.x, y: c.y - r), controlPoint1: CGPoint(x: c.x + w, y: c.y - w), controlPoint2: CGPoint(x: c.x + w, y: c.y - w))
    p.curve(to: CGPoint(x: c.x - r, y: c.y), controlPoint1: CGPoint(x: c.x - w, y: c.y - w), controlPoint2: CGPoint(x: c.x - w, y: c.y - w))
    p.curve(to: CGPoint(x: c.x, y: c.y + r), controlPoint1: CGPoint(x: c.x - w, y: c.y + w), controlPoint2: CGPoint(x: c.x - w, y: c.y + w))
    p.close()
    return p
}

func drawIcon(in ctx: CGContext) {
    // Background tile: macOS icon grid (824pt tile, 100pt margins).
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: 185, yRadius: 185)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.35)
    shadow.shadowBlurRadius = 24
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    color(0x8E5CF7).setFill()
    tilePath.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    tilePath.addClip()
    NSGradient(colors: [color(0xFFB347), color(0xF2536F), color(0x9B5CF6), color(0x3B82F6)],
               atLocations: [0, 0.35, 0.7, 1], colorSpace: .sRGB)!
        .draw(in: tile, angle: -45)
    // Soft top highlight.
    NSGradient(starting: .white.withAlphaComponent(0.28), ending: .white.withAlphaComponent(0))!
        .draw(in: CGRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2), angle: -90)
    NSGraphicsContext.restoreGraphicsState()

    // Polaroid card, tilted.
    ctx.saveGState()
    ctx.translateBy(x: 500, y: 490)
    ctx.rotate(by: -8 * .pi / 180)
    let card = CGRect(x: -235, y: -275, width: 470, height: 550)
    let cardPath = NSBezierPath(roundedRect: card, xRadius: 34, yRadius: 34)

    NSGraphicsContext.saveGraphicsState()
    let cardShadow = NSShadow()
    cardShadow.shadowColor = .black.withAlphaComponent(0.3)
    cardShadow.shadowBlurRadius = 40
    cardShadow.shadowOffset = NSSize(width: 0, height: -18)
    cardShadow.set()
    NSColor.white.setFill()
    cardPath.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Photo: sky, sun, mountains.
    let photo = CGRect(x: card.minX + 32, y: card.minY + 150, width: card.width - 64, height: card.height - 182)
    let photoPath = NSBezierPath(roundedRect: photo, xRadius: 18, yRadius: 18)
    NSGraphicsContext.saveGraphicsState()
    photoPath.addClip()
    NSGradient(starting: color(0xFFD9A0), ending: color(0x7DB7FF))!.draw(in: photo, angle: -90)
    color(0xFFF4D6).setFill()
    NSBezierPath(ovalIn: CGRect(x: photo.minX + 230, y: photo.minY + 200, width: 92, height: 92)).fill()
    let back = NSBezierPath()
    back.move(to: CGPoint(x: photo.minX - 10, y: photo.minY))
    back.line(to: CGPoint(x: photo.minX + 120, y: photo.minY + 200))
    back.line(to: CGPoint(x: photo.minX + 250, y: photo.minY + 70))
    back.line(to: CGPoint(x: photo.maxX + 10, y: photo.minY))
    back.close()
    color(0x6C63D9).setFill()
    back.fill()
    let front = NSBezierPath()
    front.move(to: CGPoint(x: photo.minX + 90, y: photo.minY))
    front.line(to: CGPoint(x: photo.minX + 270, y: photo.minY + 170))
    front.line(to: CGPoint(x: photo.maxX + 10, y: photo.minY + 40))
    front.line(to: CGPoint(x: photo.maxX + 10, y: photo.minY))
    front.close()
    color(0x3E3A9E).setFill()
    front.fill()
    NSGraphicsContext.restoreGraphicsState()

    // Caption lines.
    color(0xC9C4D6).setFill()
    NSBezierPath(roundedRect: CGRect(x: card.minX + 40, y: card.minY + 92, width: 300, height: 22), xRadius: 11, yRadius: 11).fill()
    NSBezierPath(roundedRect: CGRect(x: card.minX + 40, y: card.minY + 50, width: 200, height: 22), xRadius: 11, yRadius: 11).fill()
    ctx.restoreGState()

    // Apple Intelligence-style sparkles.
    NSGraphicsContext.saveGraphicsState()
    let glow = NSShadow()
    glow.shadowColor = color(0xFFF1B8, 0.9)
    glow.shadowBlurRadius = 30
    glow.set()
    NSColor.white.setFill()
    sparkle(at: CGPoint(x: 735, y: 745), radius: 120).fill()
    sparkle(at: CGPoint(x: 820, y: 595), radius: 52).fill()
    NSGraphicsContext.restoreGraphicsState()
}

func render(size: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let gc = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = gc
    gc.cgContext.scaleBy(x: CGFloat(size) / canvas, y: CGFloat(size) / canvas)
    drawIcon(in: gc.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try render(size: base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(size: base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try render(size: 1024).write(to: root.appendingPathComponent("docs/icon.png"))

let out = root.appendingPathComponent("Resources/AppIcon.icns")
let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", out.path]
try iconutil.run()
iconutil.waitUntilExit()
print("Wrote \(out.path)")
