import Foundation

enum Fmt {
    /// UK energy pricing is quoted in local time; the API speaks UTC.
    static let ukTimeZone = TimeZone(identifier: "Europe/London") ?? .current

    static let slotTime: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = ukTimeZone
        return f
    }()

    static let slotDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        f.timeZone = ukTimeZone
        return f
    }()

    /// `14:30` today, `Fri 02:00` otherwise — enough to disambiguate an
    /// overnight cheap window without spending width on a full date.
    static func slotLabel(_ date: Date, now: Date = Date()) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = ukTimeZone
        if cal.isDate(date, inSameDayAs: now) {
            return slotTime.string(from: date)
        }
        return "\(slotDay.string(from: date)) \(slotTime.string(from: date))"
    }

    static func range(_ start: Date, _ end: Date, now: Date = Date()) -> String {
        "\(slotLabel(start, now: now))–\(slotTime.string(from: end))"
    }

    /// Pence per kWh. Negative values keep the sign — plunge pricing is real.
    static func pence(_ value: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)fp", value)
    }

    static func signedPence(_ value: Double) -> String {
        (value >= 0 ? "+" : "") + String(format: "%.1fp", value)
    }

    static func relative(_ date: Date, now: Date = Date()) -> String {
        let seconds = Int(date.timeIntervalSince(now))
        if seconds < 0 { return "now" }
        if seconds < 60 { return "<1m" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60
        let rem = minutes % 60
        return rem == 0 ? "\(hours)h" : "\(hours)h \(rem)m"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let minutes = Int(interval.rounded()) / 60
        let hours = minutes / 60
        let rem = minutes % 60
        if hours == 0 { return "\(rem) min" }
        return rem == 0 ? "\(hours) hr" : "\(hours)h \(rem)m"
    }
}
