#!/usr/bin/env swift

import AppKit
import Foundation

let width = 920
let height = 400
let outputPath = CommandLine.arguments.dropFirst().first
    ?? "Resources/DMGBackground.png"

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: width,
    pixelsHigh: height,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Unable to create background bitmap")
}

let context = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
defer { NSGraphicsContext.restoreGraphicsState() }

NSColor(calibratedRed: 0.043, green: 0.082, blue: 0.133, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

NSColor(calibratedRed: 0.09, green: 0.20, blue: 0.23, alpha: 1).setFill()
NSBezierPath(
    ovalIn: NSRect(x: -46, y: 145, width: 356, height: 356)
).fill()

NSColor(calibratedRed: 0.09, green: 0.14, blue: 0.23, alpha: 1).setFill()
NSBezierPath(
    ovalIn: NSRect(x: 605, y: -129, width: 398, height: 398)
).fill()

func drawCentered(
    _ text: String,
    top: CGFloat,
    font: NSFont,
    alpha: CGFloat = 1
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(alpha)
    ]
    let size = (text as NSString).size(withAttributes: attributes)
    let point = NSPoint(
        x: (CGFloat(width) - size.width) / 2,
        y: CGFloat(height) - top - size.height
    )
    (text as NSString).draw(at: point, withAttributes: attributes)
}

drawCentered(
    "Quota Bar",
    top: 34,
    font: .systemFont(ofSize: 29, weight: .semibold)
)
drawCentered(
    "Quota & Work Status",
    top: 77,
    font: .systemFont(ofSize: 15, weight: .medium),
    alpha: 0.88
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 380, y: 195))
arrow.line(to: NSPoint(x: 534, y: 195))
arrow.move(to: NSPoint(x: 514, y: 215))
arrow.line(to: NSPoint(x: 536, y: 195))
arrow.line(to: NSPoint(x: 514, y: 175))
arrow.lineWidth = 6
arrow.lineCapStyle = .square
arrow.lineJoinStyle = .miter
NSColor(calibratedRed: 0.38, green: 0.90, blue: 0.76, alpha: 1).setStroke()
arrow.stroke()

drawCentered(
    "拖到 Applications 即可安装  ·  Drag to install",
    top: 299,
    font: .systemFont(ofSize: 17, weight: .medium)
)
drawCentered(
    "v1.2.3",
    top: 335,
    font: .systemFont(ofSize: 13, weight: .medium),
    alpha: 0.82
)

guard
    let png = bitmap.representation(
        using: .png,
        properties: [.compressionFactor: 0.9]
    )
else {
    fatalError("Unable to encode background PNG")
}

try png.write(to: URL(fileURLWithPath: outputPath))
