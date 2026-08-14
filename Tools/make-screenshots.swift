import AppKit
import SwiftUI

// Renders the App Store screenshots in docs/app-store/.
//
// The popover is drawn with SwiftUI's ImageRenderer against live prices from
// the Octopus public API, then composited onto a synthetic desktop. Nothing is
// captured from the real screen: that would need Screen Recording permission,
// would bake in whatever the machine's resolution happens to be, and would risk
// putting somebody's actual desktop in front of App Review.
//
// Apple accepts 1280×800, 1440×900, 2560×1600 or 2880×1800. We emit 2880×1800,
// which is 1440×900 at 2×, so everything below is expressed in points.
//
//   ./Tools/make-screenshots.sh
//
// The desktop, menu bar and status item are all drawn here rather than borrowed
// from the system: no Apple logo, no SF Symbols standing in for system UI, no
// stock wallpaper. Only the popover itself is the real app.

// MARK: - Geometry

let scale: CGFloat = 2
let pageW: CGFloat = 1440
let pageH: CGFloat = 900
let menuBarH: CGFloat = 25
let cardW: CGFloat = 340
/// The popover is 340pt wide in life, which is a postage stamp on a 1440pt
/// canvas. Enlarging it is normal for store artwork; rendering at scale ×
/// cardZoom keeps it genuinely sharp rather than upscaled.
let cardZoom: CGFloat = 1.3

// MARK: - Palette

struct Theme {
    let dark: Bool
    let skyTop: NSColor
    let skyBottom: NSColor
    let glow: NSColor
    var ink: NSColor { dark ? .white : NSColor(hex: "10131a") }
    var menuInk: NSColor { dark ? NSColor(white: 1, alpha: 0.92) : NSColor(white: 0, alpha: 0.85) }
    var menuBar: NSColor { dark ? NSColor(white: 0, alpha: 0.30) : NSColor(white: 1, alpha: 0.42) }

    /// Deep indigo through to the blue the chart uses for cheap slots — the
    /// palette the app already owns, rather than a decorative gradient that
    /// fights it.
    static let night = Theme(dark: true,
                             skyTop: NSColor(hex: "070b18"),
                             skyBottom: NSColor(hex: "163a6d"),
                             glow: NSColor(hex: "2a78d6"))

    static let day = Theme(dark: false,
                           skyTop: NSColor(hex: "cfe0f5"),
                           skyBottom: NSColor(hex: "eef2f7"),
                           glow: NSColor(hex: "3987e5"))

    /// For the peak-price shot, so the desktop is not arguing with the chart.
    static let dusk = Theme(dark: true,
                            skyTop: NSColor(hex: "1a0d14"),
                            skyBottom: NSColor(hex: "5c2333"),
                            glow: NSColor(hex: "c33a3a"))
}

// MARK: - Drawing helpers

func drawSky(_ ctx: CGContext, _ theme: Theme) {
    let space = CGColorSpaceCreateDeviceRGB()
    let colors = [theme.skyTop.cgColor, theme.skyBottom.cgColor] as CFArray
    if let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1]) {
        // Both extend options matter: the axis is diagonal and stops short of
        // two corners, which otherwise come out as hard unpainted wedges.
        ctx.drawLinearGradient(g, start: CGPoint(x: pageW * 0.15, y: pageH),
                               end: CGPoint(x: pageW * 0.85, y: 0),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }
    // A soft light source behind the card lifts it off the flat gradient.
    let glow = [theme.glow.withAlphaComponent(theme.dark ? 0.42 : 0.30).cgColor,
                theme.glow.withAlphaComponent(0).cgColor] as CFArray
    if let g = CGGradient(colorsSpace: space, colors: glow, locations: [0, 1]) {
        ctx.drawRadialGradient(g,
                               startCenter: CGPoint(x: pageW * 0.66, y: pageH * 0.62), startRadius: 0,
                               endCenter: CGPoint(x: pageW * 0.66, y: pageH * 0.62), endRadius: pageW * 0.45,
                               options: [])
    }
}

func text(_ string: String, _ font: NSFont, _ color: NSColor,
          at point: CGPoint, align: NSTextAlignment = .left, maxWidth: CGFloat? = nil) {
    let para = NSMutableParagraphStyle()
    para.alignment = align
    para.lineSpacing = 2
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: para]
    let attributed = NSAttributedString(string: string, attributes: attrs)
    if let maxWidth {
        let rect = CGRect(x: point.x, y: point.y, width: maxWidth,
                          height: attributed.boundingRect(with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
                                                          options: .usesLineFragmentOrigin).height)
        attributed.draw(with: rect, options: .usesLineFragmentOrigin)
    } else {
        attributed.draw(at: point)
    }
}

func width(_ string: String, _ font: NSFont) -> CGFloat {
    NSAttributedString(string: string, attributes: [.font: font]).size().width
}

/// The macOS menu bar, drawn rather than screenshotted. Deliberately carries no
/// Apple logo and no system menu titles.
func drawMenuBar(_ ctx: CGContext, _ theme: Theme, statusX: CGFloat, price: String, dotColor: NSColor) {
    ctx.saveGState()
    theme.menuBar.setFill()
    ctx.fill(CGRect(x: 0, y: pageH - menuBarH, width: pageW, height: menuBarH))
    ctx.restoreGState()

    let bar = pageH - menuBarH
    let midY = bar + menuBarH / 2
    let font = NSFont.systemFont(ofSize: 13, weight: .regular)

    // The app's own status item.
    let dotR: CGFloat = 3.5
    dotColor.setFill()
    ctx.fillEllipse(in: CGRect(x: statusX, y: midY - dotR, width: dotR * 2, height: dotR * 2))
    text(price, NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium), theme.menuInk,
         at: CGPoint(x: statusX + dotR * 2 + 6, y: midY - 8))

    // Generic neighbours so the bar does not read as empty. Drawn by hand: no
    // SF Symbols standing in for system controls.
    var x = pageW - 22
    let clock = "09:41"
    x -= width(clock, font)
    text(clock, font, theme.menuInk, at: CGPoint(x: x, y: midY - 8))
    x -= 20

    // Battery
    let bw: CGFloat = 22, bh: CGFloat = 11
    x -= bw
    let body = CGRect(x: x, y: midY - bh / 2, width: bw, height: bh)
    ctx.setStrokeColor(theme.menuInk.withAlphaComponent(0.55).cgColor)
    ctx.setLineWidth(1.2)
    ctx.addPath(CGPath(roundedRect: body, cornerWidth: 3, cornerHeight: 3, transform: nil))
    ctx.strokePath()
    theme.menuInk.withAlphaComponent(0.85).setFill()
    ctx.fill(CGRect(x: x + 2, y: midY - bh / 2 + 2, width: (bw - 4) * 0.7, height: bh - 4))
    ctx.fill(CGRect(x: x + bw + 1.5, y: midY - 2, width: 1.6, height: 4))
    x -= 18

    // Wi-Fi: three arcs and a dot.
    let cx = x, cy = midY - 5
    ctx.setStrokeColor(theme.menuInk.withAlphaComponent(0.85).cgColor)
    for (i, r) in [3.5, 7.0, 10.5].enumerated() {
        ctx.setLineWidth(i == 0 ? 2.0 : 1.8)
        ctx.addArc(center: CGPoint(x: cx, y: cy), radius: r,
                   startAngle: .pi / 5, endAngle: .pi * 4 / 5, clockwise: false)
        ctx.strokePath()
    }
    theme.menuInk.withAlphaComponent(0.85).setFill()
    ctx.fillEllipse(in: CGRect(x: cx - 1.6, y: cy - 1.6, width: 3.2, height: 3.2))
}

/// The popover, with the little pointer that ties it to the status item.
func drawCard(_ ctx: CGContext, image: CGImage, size: CGSize, x: CGFloat, top: CGFloat, pointerX: CGFloat) {
    let rect = CGRect(x: x, y: top - size.height, width: size.width, height: size.height)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 48,
                  color: NSColor(white: 0, alpha: 0.44).cgColor)

    // Pointer and body are filled as one shape so the shadow wraps both.
    let path = CGMutablePath()
    path.addRoundedRect(in: rect, cornerWidth: 11, cornerHeight: 11)
    path.move(to: CGPoint(x: pointerX - 9, y: top))
    path.addLine(to: CGPoint(x: pointerX, y: top + 8))
    path.addLine(to: CGPoint(x: pointerX + 9, y: top))
    path.closeSubpath()
    ctx.addPath(path)
    NSColor(white: 0.5, alpha: 1).setFill()   // hidden behind the image; shadow caster only
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 11, cornerHeight: 11, transform: nil))
    ctx.clip()
    ctx.draw(image, in: rect)
    ctx.restoreGState()

    // Hairline edge, so the card still reads against a pale desktop.
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerWidth: 11, cornerHeight: 11, transform: nil))
    ctx.setStrokeColor(NSColor(white: 0.5, alpha: 0.35).cgColor)
    ctx.setLineWidth(1)
    ctx.strokePath()
    ctx.restoreGState()
}

// MARK: - Rendering the real view

/// Photographs the popover through an offscreen `NSHostingView`.
///
/// SwiftUI's `ImageRenderer` is the obvious tool and is wrong for this: it
/// cannot rasterise AppKit-backed controls, so the settings face comes out with
/// yellow placeholders where the region picker, postcode field and checkboxes
/// should be. `cacheDisplay(in:to:)` walks the real view hierarchy and draws
/// them properly — and needs no Screen Recording permission, because this is
/// our own window rather than the screen.
@MainActor
func renderPopover(store: RatesStore, settings: Settings,
                   dark: Bool, settingsFace: Bool) -> (image: CGImage, size: CGSize)? {
    let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)!
    NSApp.appearance = appearance

    func host(zoom: CGFloat, natural: CGSize?) -> NSHostingView<AnyView> {
        var content = AnyView(PopoverView(store: store, settings: settings, showingSettings: settingsFace)
            .environment(\.colorScheme, dark ? .dark : .light)
            .frame(width: cardW))
        if let natural, zoom != 1 {
            // Pin to the measured size, scale about the top-left, then re-frame
            // to the scaled box. Without the first frame, scaleEffect anchors
            // against the proposed size and the content walks off the canvas.
            content = AnyView(content
                .frame(width: natural.width, height: natural.height)
                .scaleEffect(zoom, anchor: .topLeading)
                .frame(width: natural.width * zoom, height: natural.height * zoom, alignment: .topLeading))
        }
        let view = NSHostingView(rootView: content)
        view.appearance = appearance
        if let natural {
            view.frame = CGRect(origin: .zero,
                                size: CGSize(width: natural.width * zoom, height: natural.height * zoom))
        }
        return view
    }

    // Measure at natural size, then re-host scaled up so glyphs are rasterised
    // at the final density rather than resampled from a 340pt bitmap.
    let natural = host(zoom: 1, natural: nil).fittingSize
    guard natural.width > 0, natural.height > 0 else { return nil }
    let view = host(zoom: cardZoom, natural: natural)

    let window = NSWindow(contentRect: view.frame, styleMask: [.borderless],
                          backing: .buffered, defer: false)
    window.appearance = appearance
    window.contentView = view
    window.displayIfNeeded()
    view.layoutSubtreeIfNeeded()

    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let image = rep.cgImage else { return nil }

    // Report the size to draw at in points, rather than deriving it from the
    // bitmap: the offscreen window inherits the main screen's backing scale,
    // which is 1 on a non-Retina Mac and would otherwise halve the card.
    return (image, CGSize(width: natural.width * cardZoom, height: natural.height * cardZoom))
}

// MARK: - One screenshot

struct Shot {
    let name: String
    let theme: Theme
    let headline: String
    let sub: String
    let settingsFace: Bool
}

@MainActor
func compose(_ shot: Shot, store: RatesStore, settings: Settings, outDir: String) {
    guard let (card, cardSize) = renderPopover(store: store, settings: settings,
                                               dark: shot.theme.dark, settingsFace: shot.settingsFace) else {
        print("!! \(shot.name): the popover rendered to nothing"); return
    }

    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: Int(pageW * scale), pixelsHigh: Int(pageH * scale),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .calibratedRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let nsCtx = NSGraphicsContext(bitmapImageRep: rep) else { return }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx
    let ctx = nsCtx.cgContext
    ctx.scaleBy(x: scale, y: scale)

    drawSky(ctx, shot.theme)

    // Card sits right of centre; the copy takes the left column.
    let drawnW = cardSize.width
    let drawnH = cardSize.height
    let cardX = pageW - drawnW - 120
    let statusX = cardX + 110
    let cardTop = pageH - menuBarH - 12

    let priceText: String
    var dot = PriceBand.typical.color
    if let current = store.currentRate {
        let band = store.band(for: current)
        priceText = Fmt.pence(store.price(current), decimals: 1)
        dot = band.color
    } else {
        priceText = "—"
    }
    let dotNS = NSColor(dot).usingColorSpace(.sRGB) ?? .systemGray

    drawMenuBar(ctx, shot.theme, statusX: statusX, price: priceText, dotColor: dotNS)
    drawCard(ctx, image: card, size: cardSize, x: cardX, top: cardTop, pointerX: statusX + 12)

    // Copy block, vertically centred against the card.
    let copyX: CGFloat = 96
    let copyW = cardX - copyX - 90
    let headFont = NSFont.systemFont(ofSize: 46, weight: .semibold)
    let subFont = NSFont.systemFont(ofSize: 21, weight: .regular)
    let headHeight = NSAttributedString(string: shot.headline, attributes: [.font: headFont])
        .boundingRect(with: CGSize(width: copyW, height: .greatestFiniteMagnitude),
                      options: .usesLineFragmentOrigin).height
    let subHeight = NSAttributedString(string: shot.sub, attributes: [.font: subFont])
        .boundingRect(with: CGSize(width: copyW, height: .greatestFiniteMagnitude),
                      options: .usesLineFragmentOrigin).height
    let block = headHeight + 18 + subHeight
    // Centred against the card, not the page: the popover hangs from the menu
    // bar, so page-centred copy floats well below it and leaves a dead band.
    let top = (cardTop + (cardTop - drawnH)) / 2 + block / 2

    text(shot.headline, headFont, shot.theme.ink,
         at: CGPoint(x: copyX, y: top - headHeight), maxWidth: copyW)
    text(shot.sub, subFont, shot.theme.ink.withAlphaComponent(0.72),
         at: CGPoint(x: copyX, y: top - headHeight - 18 - subHeight), maxWidth: copyW)

    NSGraphicsContext.restoreGraphicsState()

    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent("\(shot.name).png")
    try? data.write(to: url)
    print("  \(shot.name).png  \(Int(pageW * scale))×\(Int(pageH * scale))")
}

// MARK: - Main

let shots = [
    Shot(name: "01-menu-bar",
         theme: .night,
         headline: "No account.\nNo API key.\nNo hardware.",
         sub: "The live Agile unit rate sits in your menu bar and updates itself every half hour. It reads the public Octopus tariff feed, so there is nothing to sign in to.",
         settingsFace: false),
    Shot(name: "02-whole-day",
         theme: .day,
         headline: "The whole day,\nat a glance.",
         sub: "Every published half hour as a chart, coloured against the rest of the day — blue for cheaper than usual, red for dearer. It re-bases daily, so it stays honest as the market moves.",
         settingsFace: false),
    Shot(name: "03-best-window",
         theme: .dusk,
         headline: "Know the cheapest\ntwo hours.",
         sub: "The dishwasher, the EV, the dryer. Agile Bar finds the cheapest contiguous two-hour run ahead, alongside the cheapest and priciest single slots.",
         settingsFace: false),
    Shot(name: "04-settings",
         theme: .night,
         headline: "Your region,\nin two clicks.",
         sub: "Pick a grid region or type a postcode and let the app look it up. Show prices with or without VAT, and open at login if you want it always there.",
         settingsFace: true),
]

@main
enum ScreenshotTool {
    static func main() async {
        let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/app-store"
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

        NSApplication.shared.setActivationPolicy(.prohibited)

        let settings = await Settings.shared
        await MainActor.run {
            settings.region = .c
            settings.includeVAT = true
        }

        let store = await RatesStore(settings: settings)
        await store.load()

        let (state, count, windowCount) = await MainActor.run {
            (store.state, store.rates.count, store.window.count)
        }
        guard case .loaded = state, count > 0 else {
            print("Could not fetch prices from Octopus (\(state)).")
            print("Screenshots render against live data on purpose — try again when online.")
            exit(1)
        }
        print("==> \(count) live slots, \(windowCount) in the visible window")

        print("==> Composing")
        for shot in shots {
            await compose(shot, store: store, settings: settings, outDir: outDir)
        }
        print("Wrote \(shots.count) screenshots to \(outDir)")
    }
}
