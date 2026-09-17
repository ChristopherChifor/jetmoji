import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

func drawIcon(size: CGFloat, radius: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let inset = NSInsetRect(rect, size * 0.02, size * 0.02)
        let path = NSBezierPath(roundedRect: inset, xRadius: radius, yRadius: radius)

        let base = NSGradient(colors: [
            NSColor(srgbRed: 0.07, green: 0.09, blue: 0.14, alpha: 1),
            NSColor(srgbRed: 0.03, green: 0.04, blue: 0.07, alpha: 1),
        ])
        base?.draw(in: path, angle: 90)

        let glow = NSGradient(colors: [
            NSColor(srgbRed: 1.0, green: 0.42, blue: 0.18, alpha: 0.45),
            NSColor(srgbRed: 0.36, green: 0.88, blue: 1.0, alpha: 0.0),
        ])
        let glowRect = NSRect(
            x: rect.midX - size * 0.18,
            y: rect.minY + size * 0.08,
            width: size * 0.36,
            height: size * 0.55
        )
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        glow?.draw(in: glowRect, relativeCenterPosition: .zero)
        NSGraphicsContext.restoreGraphicsState()

        let jet = NSBezierPath()
        let cx = rect.midX
        let cy = rect.midY + size * 0.02
        jet.move(to: NSPoint(x: cx - size * 0.28, y: cy - size * 0.18))
        jet.line(to: NSPoint(x: cx + size * 0.32, y: cy + size * 0.02))
        jet.line(to: NSPoint(x: cx - size * 0.28, y: cy + size * 0.22))
        jet.line(to: NSPoint(x: cx - size * 0.12, y: cy + size * 0.02))
        jet.close()

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSColor(srgbRed: 0.36, green: 0.88, blue: 1.0, alpha: 1).setFill()
        jet.fill()

        let window = NSBezierPath(ovalIn: NSRect(
            x: cx + size * 0.08,
            y: cy - size * 0.03,
            width: size * 0.09,
            height: size * 0.09
        ))
        NSColor(srgbRed: 1.0, green: 0.85, blue: 0.20, alpha: 1).setFill()
        window.fill()

        let smile = NSBezierPath()
        smile.move(to: NSPoint(x: cx + size * 0.095, y: cy + size * 0.005))
        smile.curve(
            to: NSPoint(x: cx + size * 0.155, y: cy + size * 0.005),
            controlPoint1: NSPoint(x: cx + size * 0.11, y: cy - size * 0.015),
            controlPoint2: NSPoint(x: cx + size * 0.14, y: cy - size * 0.015)
        )
        NSColor(srgbRed: 0.07, green: 0.09, blue: 0.14, alpha: 1).setStroke()
        smile.lineWidth = max(1.5, size * 0.008)
        smile.lineCapStyle = .round
        smile.stroke()
        NSGraphicsContext.restoreGraphicsState()
        return true
    }
}

func pngData(_ image: NSImage, width: Int, height: Int) -> Data {
    let scaled = NSImage(size: NSSize(width: width, height: height))
    scaled.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(
        in: NSRect(x: 0, y: 0, width: width, height: height),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    scaled.unlockFocus()
    guard let tiff = scaled.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

func drawStatus(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        let path = NSBezierPath()
        let s = size
        path.move(to: NSPoint(x: s * 0.12, y: s * 0.28))
        path.line(to: NSPoint(x: s * 0.88, y: s * 0.50))
        path.line(to: NSPoint(x: s * 0.12, y: s * 0.72))
        path.line(to: NSPoint(x: s * 0.32, y: s * 0.50))
        path.close()
        NSColor.black.setFill()
        path.fill()
        return true
    }
}

let master = drawIcon(size: 1024, radius: 224)
try pngData(master, width: 1024, height: 1024).write(to: assets.appendingPathComponent("AppIcon.png"))

let iconset = assets.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(String, Int)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]
for (name, pixels) in sizes {
    try pngData(master, width: pixels, height: pixels).write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", assets.appendingPathComponent("AppIcon.icns").path, iconset.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    fatalError("iconutil failed")
}

let status = drawStatus(size: 18)
let status2x = drawStatus(size: 36)
try pngData(status, width: 18, height: 18).write(to: assets.appendingPathComponent("StatusItem.png"))
try pngData(status2x, width: 36, height: 36).write(to: assets.appendingPathComponent("StatusItem@2x.png"))
print("Wrote icons in \(assets.path)")
