import Foundation

/// A single half-hourly Agile unit rate, in pence per kWh.
struct Rate: Codable, Hashable, Identifiable {
    let validFrom: Date
    /// `nil` on the open-ended final rate the API occasionally returns.
    let validTo: Date?
    let valueIncVat: Double
    let valueExcVat: Double

    var id: Date { validFrom }

    /// Agile slots are always half-hourly; synthesise the end when the API omits it.
    var end: Date { validTo ?? validFrom.addingTimeInterval(1800) }

    func contains(_ date: Date) -> Bool {
        date >= validFrom && date < end
    }

    enum CodingKeys: String, CodingKey {
        case validFrom = "valid_from"
        case validTo = "valid_to"
        case valueIncVat = "value_inc_vat"
        case valueExcVat = "value_exc_vat"
    }
}

/// A run of consecutive slots — used for "cheapest 2 hours to run the dishwasher".
struct RateWindow: Hashable {
    let start: Date
    let end: Date
    let averagePence: Double
    let slotCount: Int

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

extension Array where Element == Rate {
    /// Ascending by start time, de-duplicated on `validFrom`.
    func normalised() -> [Rate] {
        var seen = Set<Date>()
        return filter { seen.insert($0.validFrom).inserted }
            .sorted { $0.validFrom < $1.validFrom }
    }

    func rate(at date: Date) -> Rate? {
        first { $0.contains(date) }
    }

    /// Slots that have not finished yet, capped at `hours` ahead of `date`.
    func upcoming(from date: Date, hours: Double) -> [Rate] {
        let horizon = date.addingTimeInterval(hours * 3600)
        return filter { $0.end > date && $0.validFrom < horizon }
    }

    /// Cheapest contiguous run of `slotCount` slots at or after `date`.
    ///
    /// Returns `nil` unless a genuinely contiguous run exists — Agile data can have
    /// gaps around the daily publish, and averaging across a gap would be a lie.
    func cheapestWindow(slots slotCount: Int, from date: Date) -> RateWindow? {
        let candidates = filter { $0.end > date }
        guard slotCount > 0, candidates.count >= slotCount else { return nil }

        var best: RateWindow?
        for start in 0...(candidates.count - slotCount) {
            let run = Array(candidates[start..<(start + slotCount)])
            let contiguous = zip(run, run.dropFirst()).allSatisfy { $0.end == $1.validFrom }
            guard contiguous else { continue }

            let mean = run.reduce(0) { $0 + $1.valueIncVat } / Double(slotCount)
            if best == nil || mean < best!.averagePence {
                best = RateWindow(start: run[0].validFrom,
                                  end: run[run.count - 1].end,
                                  averagePence: mean,
                                  slotCount: slotCount)
            }
        }
        return best
    }
}
