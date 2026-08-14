import Foundation

/// DNO / Grid Supply Point group. Agile prices differ per region.
enum Region: String, CaseIterable, Identifiable, Codable {
    case a = "A", b = "B", c = "C", d = "D", e = "E", f = "F", g = "G"
    case h = "H", j = "J", k = "K", l = "L", m = "M", n = "N", p = "P"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .a: "Eastern England"
        case .b: "East Midlands"
        case .c: "London"
        case .d: "North Wales & Merseyside"
        case .e: "West Midlands"
        case .f: "North East England"
        case .g: "North West England"
        case .h: "Southern England"
        case .j: "South East England"
        case .k: "South Wales"
        case .l: "South West England"
        case .m: "Yorkshire"
        case .n: "Southern Scotland"
        case .p: "Northern Scotland"
        }
    }

    var label: String { "\(rawValue) — \(name)" }

    /// The API reports GSP groups as `_C`; accept either form.
    init?(groupID: String) {
        self.init(rawValue: groupID.replacingOccurrences(of: "_", with: "").uppercased())
    }
}
