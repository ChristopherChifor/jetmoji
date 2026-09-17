import AppKit
import CoreText
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

func drawAppIcon(in rect: NSRect) {
    let radius = rect.width * 0.223
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    NSColor.black.setFill()
    path.fill()

    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    ctx.saveGState()
    path.addClip()

    let fontSize = rect.width * 0.70
    let font = CTFontCreateWithName("Apple Color Emoji" as CFString, fontSize, nil)
    let attributed = NSAttributedString(string: "😂", attributes: [.font: font])
    let line = CTLineCreateWithAttributedString(attributed)

    ctx.textPosition = .zero
    let ink = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: rect.midX - ink.midX, y: rect.midY - ink.midY)
    CTLineDraw(line, ctx)
    ctx.restoreGState()
}

func pngData(pixels: Int, template: Bool = false, draw: (NSRect) -> Void) -> Data {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Could not create bitmap")
    }
    rep.size = NSSize(width: pixels, height: pixels)

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    draw(NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()

    if template {
        convertToTemplate(rep)
    }

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("Could not encode PNG")
    }
    return data
}

func convertToTemplate(_ rep: NSBitmapImageRep) {
    guard let data = rep.bitmapData else { return }
    let spp = max(rep.samplesPerPixel, 4)
    let bpr = rep.bytesPerRow
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            let i = y * bpr + x * spp
            let a = Double(data[i + 3]) / 255
            if a < 0.02 {
                data[i] = 0
                data[i + 1] = 0
                data[i + 2] = 0
                data[i + 3] = 0
                continue
            }
            let r = min(1, Double(data[i]) / 255 / a)
            let g = min(1, Double(data[i + 1]) / 255 / a)
            let b = min(1, Double(data[i + 2]) / 255 / a)
            let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
            let coverage = a * (0.16 + 0.84 * (1 - luma))
            data[i] = 0
            data[i + 1] = 0
            data[i + 2] = 0
            data[i + 3] = UInt8(clamping: Int((coverage * 255).rounded()))
        }
    }
}

func drawStatus(in rect: NSRect) {
    guard let ctx = NSGraphicsContext.current?.cgContext else { return }
    let font = CTFontCreateWithName("Apple Color Emoji" as CFString, rect.width * 0.92, nil)
    let attributed = NSAttributedString(string: "😂", attributes: [.font: font])
    let line = CTLineCreateWithAttributedString(attributed)
    ctx.textPosition = .zero
    let ink = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: rect.midX - ink.midX, y: rect.midY - ink.midY)
    CTLineDraw(line, ctx)
}

try pngData(pixels: 1024, draw: drawAppIcon).write(to: assets.appendingPathComponent("AppIcon.png"))

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
    try pngData(pixels: pixels, draw: drawAppIcon).write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", assets.appendingPathComponent("AppIcon.icns").path, iconset.path]
try process.run()
process.waitUntilExit()
if process.terminationStatus != 0 {
    fatalError("iconutil failed")
}

try pngData(pixels: 18, template: true, draw: drawStatus).write(to: assets.appendingPathComponent("StatusItem.png"))
try pngData(pixels: 36, template: true, draw: drawStatus).write(to: assets.appendingPathComponent("StatusItem@2x.png"))
print("Wrote icons in \(assets.path)")
