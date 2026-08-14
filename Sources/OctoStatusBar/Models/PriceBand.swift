import SwiftUI

/// Where a slot sits in the price distribution of the visible window.
///
/// This is a *diverging* encoding around the window median, not a set of
/// categories: the question a user actually asks is "is now cheap or dear
/// compared with the rest of today?". Colour runs blue (cheap) → grey
/// (typical) → red (dear), and every use is paired with `label` so meaning is
/// never carried by colour alone.
enum PriceBand: Int, CaseIterable, Comparable {
    case plunge      // below zero — paid to consume
    case cheapest
    case cheap
    case typical
    case pricey
    case priciest

    static func < (a: PriceBand, b: PriceBand) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .plunge: "Plunge"
        case .cheapest: "Cheapest"
        case .cheap: "Cheap"
        case .typical: "Typical"
        case .pricey: "Dear"
        case .priciest: "Priciest"
        }
    }

    /// Short verdict shown next to the headline price.
    var verdict: String {
        switch self {
        case .plunge: "You're paid to use power"
        case .cheapest: "Cheapest slots today"
        case .cheap: "Cheaper than usual"
        case .typical: "About average"
        case .pricey: "Dearer than usual"
        case .priciest: "Peak — hold off if you can"
        }
    }

    var symbolName: String {
        switch self {
        case .plunge: "bolt.fill"
        case .cheapest: "arrow.down.circle.fill"
        case .cheap: "arrow.down.right.circle.fill"
        case .typical: "equal.circle.fill"
        case .pricey: "arrow.up.right.circle.fill"
        case .priciest: "exclamationmark.circle.fill"
        }
    }

    /// Validated diverging ramp — see README for the palette provenance.
    /// Each arm is a single hue, monotone in lightness, and clears the
    /// contrast floor against its own surface in both appearances.
    var color: Color {
        switch self {
        case .plunge:   Color(light: "1c5cab", dark: "2a78d6")
        case .cheapest: Color(light: "1c5cab", dark: "2a78d6")
        case .cheap:    Color(light: "3987e5", dark: "5598e7")
        case .typical:  Color(light: "8f8e88", dark: "6e6d68")
        case .pricey:   Color(light: "dd5c5c", dark: "e06a6a")
        case .priciest: Color(light: "a82424", dark: "c33a3a")
        }
    }

    /// Assigns a band by rank within `window`, so the scale re-bases itself
    /// each day instead of relying on thresholds that go stale as the
    /// wholesale market moves.
    static func band(for value: Double, in window: [Double]) -> PriceBand {
        if value < 0 { return .plunge }
        guard window.count >= 4 else { return .typical }

        let sorted = window.sorted()
        // Fraction of the window strictly cheaper than this slot.
        let below = sorted.firstIndex { $0 >= value } ?? sorted.count
        let rank = Double(below) / Double(sorted.count)

        switch rank {
        case ..<0.15: return .cheapest
        case ..<0.35: return .cheap
        case ..<0.65: return .typical
        case ..<0.85: return .pricey
        default:      return .priciest
        }
    }
}

extension Color {
    /// Appearance-aware colour from two hex strings. Dark mode is *selected*,
    /// not derived by flipping the light value.
    init(light: String, dark: String) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: isDark ? dark : light)
        })
    }
}

extension NSColor {
    convenience init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
                  green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255,
                  alpha: 1)
    }
}
