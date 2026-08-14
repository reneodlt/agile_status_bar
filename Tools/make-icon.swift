#!/usr/bin/env swift
//
// Renders Resources/AppIcon.iconset from code.
//
// The mark is drawn with plain Bézier paths rather than an SF Symbol: Apple's
// SF Symbols licence forbids using the symbols in app icons.
//
// Usage: swift Tools/make-icon.swift <output-iconset-dir>

import AppKit

let outputDir = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Resources/AppIcon.iconset"

/// macOS icons sit on a rounded tile inset from the canvas edge, with a corner
/// radius proportional to the tile — these are Apple's published ratios.
let tileInsetRatio: CGFloat = 0.098
let cornerRatio: CGFloat = 0.2237

func color(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1)
}

/// Lightning bolt, in a unit square with y running upward.
func boltPath(in rect: CGRect) -> NSBezierPath {
    // Wide shoulders and a generous gap between them keep the waist from
    // thinning to a sliver once the icon is scaled down to 16pt.
    let points: [(CGFloat, CGFloat)] = [
        (0.66, 1.00),
        (0.06, 0.42),
        (0.40, 0.42),
        (0.34, 0.00),
        (0.94, 0.58),
        (0.60, 0.58),
    ]
    let path = NSBezierPath()
    for (index, point) in points.enumerated() {
        let p = CGPoint(x: rect.minX + point.0 * rect.width,
                        y: rect.minY + point.1 * rect.height)
        if index == 0 { path.move(to: p) } else { path.line(to: p) }
    }
    path.close()
    return path
}

func renderIcon(pixels: Int) -> Data {
    let size = CGFloat(pixels)
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4,
                                     hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else {
        fatalError("could not allocate bitmap")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high

    let inset = size * tileInsetRatio
    let tile = CGRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    let radius = tile.width * cornerRatio

    // Tile: deep navy so the bolt reads as light-on-dark at every size.
    let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
    let backdrop = NSGradient(colors: [color(0x16305A), color(0x0B1B33)],
                              atLocations: [0, 1],
                              colorSpace: .sRGB)
    backdrop?.draw(in: tilePath, angle: -90)

    // A hairline lip stops the tile dissolving into a dark desktop.
    color(0xFFFFFF).withAlphaComponent(0.10).setStroke()
    tilePath.lineWidth = max(size * 0.004, 0.5)
    tilePath.stroke()

    // Bolt, centred and sized against the tile rather than the full canvas.
    let boltHeight = tile.height * 0.66
    let boltWidth = boltHeight * 0.78
    let boltRect = CGRect(x: tile.midX - boltWidth / 2,
                          y: tile.midY - boltHeight / 2,
                          width: boltWidth, height: boltHeight)
    let bolt = boltPath(in: boltRect)
    let boltFill = NSGradient(colors: [color(0xEAF3FF), color(0x86B6EF)],
                             atLocations: [0, 1],
                             colorSpace: .sRGB)
    boltFill?.draw(in: bolt, angle: -90)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else {
        fatalError("could not encode PNG")
    }
    return data
}

// (filename, pixel size) — the full set `iconutil` expects.
let variants: [(String, Int)] = [
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

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

var cache: [Int: Data] = [:]
for (name, pixels) in variants {
    let data = cache[pixels] ?? renderIcon(pixels: pixels)
    cache[pixels] = data
    let path = (outputDir as NSString).appendingPathComponent(name)
    try! data.write(to: URL(fileURLWithPath: path))
    print("  \(name)  \(pixels)×\(pixels)")
}

print("Wrote \(variants.count) images to \(outputDir)")
