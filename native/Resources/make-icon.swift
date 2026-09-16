import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("usage: make-icon.swift OUTPUT.icns\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fileManager = FileManager.default
let temporaryDirectory = fileManager.temporaryDirectory
    .appendingPathComponent("go-outside-icon-\(ProcessInfo.processInfo.processIdentifier)", isDirectory: true)
let iconsetURL = temporaryDirectory.appendingPathExtension("iconset")
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
defer { try? fileManager.removeItem(at: temporaryDirectory) }

let sizes = [16, 32, 128, 256, 512]
for size in sizes {
    for scale in [1, 2] {
        let pixelSize = CGFloat(size * scale)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(pixelSize), pixelsHigh: Int(pixelSize),
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                            isPlanar: false, colorSpaceName: .deviceRGB,
                                            bitmapFormat: [], bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { continue }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        let cgContext = context.cgContext
        cgContext.setAllowsAntialiasing(true)
        cgContext.setShouldAntialias(true)

        let bounds = CGRect(x: pixelSize * 0.10, y: pixelSize * 0.10,
                            width: pixelSize * 0.80, height: pixelSize * 0.80)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let radius = bounds.width / 2

        NSColor.white.setFill()
        NSBezierPath(ovalIn: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize)).fill()

        // A fresh ratio-circle mark: the solid sector begins at 12 o'clock and
        // leaves a clear sector so the comparison remains legible at small sizes.
        NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
        let sector = NSBezierPath()
        sector.move(to: center)
        sector.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 240, clockwise: true)
        sector.close()
        sector.fill()

        NSColor(calibratedWhite: 0.08, alpha: 1).setStroke()
        let outline = NSBezierPath(ovalIn: bounds)
        outline.lineWidth = max(1, pixelSize / 32)
        outline.stroke()
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.representation(using: NSBitmapImageRep.FileType.png, properties: [:]) else { continue }
        let suffix = "\(size)x\(size)" + (scale == 2 ? "@2x" : "")
        try data.write(to: iconsetURL.appendingPathComponent("icon_\(suffix).png"))
    }
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", "-o", outputURL.path, iconsetURL.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else { exit(process.terminationStatus) }
