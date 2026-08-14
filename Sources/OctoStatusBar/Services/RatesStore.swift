import Foundation
import Combine

@MainActor
final class RatesStore: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)
    }

    @Published private(set) var rates: [Rate] = []
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var lastUpdated: Date?
    /// Bumped on the half hour so time-sensitive views recompute.
    @Published private(set) var now: Date = Date()

    /// How far ahead the popover summarises. Agile publishes the next day's
    /// prices around 16:00 UK time, so this is often ~30h of data by evening
    /// and only ~8h in the morning.
    static let horizonHours: Double = 24

    private let api: OctopusAPI
    private let settings: Settings
    private var productCode: String?
    private var refreshTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    init(api: OctopusAPI = OctopusAPI(), settings: Settings = .shared) {
        self.api = api
        self.settings = settings
        self.rates = RatesCache.load(region: settings.region)

        // A region change invalidates everything on screen, so drop the cached
        // series immediately rather than showing another region's prices.
        settings.$region
            .dropFirst()
            .sink { [weak self] region in
                guard let self else { return }
                self.rates = RatesCache.load(region: region)
                self.refresh()
            }
            .store(in: &cancellables)
    }

    // MARK: - Derived values

    var currentRate: Rate? { rates.rate(at: now) }

    var nextRate: Rate? {
        guard let current = currentRate else {
            return rates.first { $0.validFrom > now }
        }
        return rates.first { $0.validFrom >= current.end }
    }

    var window: [Rate] { rates.upcoming(from: now, hours: Self.horizonHours) }

    var windowValues: [Double] { window.map(\.valueIncVat) }

    var cheapest: Rate? { window.min { $0.valueIncVat < $1.valueIncVat } }

    var priciest: Rate? { window.max { $0.valueIncVat < $1.valueIncVat } }

    var average: Double? {
        let values = windowValues
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    /// Mean over the window in whichever VAT basis the user picked, averaged
    /// from the API's own figures rather than derived from the inc-VAT mean.
    var displayAverage: Double? {
        let slots = window
        guard !slots.isEmpty else { return nil }
        return slots.reduce(0) { $0 + price($1) } / Double(slots.count)
    }

    /// How far ahead prices are actually known — the honest answer to
    /// "lowest in the next 24 hours" when only 9 hours are published.
    var coverageEnd: Date? { window.last?.end }

    var coversFullHorizon: Bool {
        guard let end = coverageEnd else { return false }
        return end >= now.addingTimeInterval(Self.horizonHours * 3600 - 1800)
    }

    func band(for rate: Rate) -> PriceBand {
        PriceBand.band(for: rate.valueIncVat, in: windowValues)
    }

    func price(_ rate: Rate) -> Double {
        settings.includeVAT ? rate.valueIncVat : rate.valueExcVat
    }

    /// Cheapest contiguous run of the given length, for load-shifting.
    func cheapestWindow(hours: Double) -> RateWindow? {
        rates.cheapestWindow(slots: Int(hours * 2), from: now)
    }

    // MARK: - Loading

    func refresh() {
        refreshTask?.cancel()
        refreshTask = Task { await self.load() }
    }

    func load() async {
        state = .loading
        let region = settings.region

        do {
            let code: String
            if let cached = productCode {
                code = cached
            } else {
                code = (try? await api.currentAgileProductCode()) ?? OctopusAPI.fallbackProductCode
                productCode = code
            }

            // Reach back an hour so the in-progress slot is always present,
            // and forward far enough to catch tomorrow's publish.
            let from = now.addingTimeInterval(-3600)
            let to = now.addingTimeInterval(52 * 3600)
            let fetched = try await api.rates(productCode: code, region: region, from: from, to: to)

            guard !Task.isCancelled else { return }
            guard !fetched.isEmpty else {
                state = .failed("Octopus returned no prices for region \(region.rawValue).")
                return
            }

            rates = fetched
            lastUpdated = Date()
            state = .loaded
            RatesCache.save(fetched, region: region)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            // Cached prices stay on screen; the popover shows the staleness.
            state = .failed(error.localizedDescription)
        }
    }

    func tick() {
        now = Date()
    }
}

// MARK: - Disk cache

/// Keeps the last good series so the menu bar shows a price instantly at login
/// and stays useful through a network blip.
private enum RatesCache {
    private static var directory: URL? {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                                  in: .userDomainMask).first else { return nil }
        let dir = base.appending(path: "OctoStatusBar", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static func url(region: Region) -> URL? {
        directory?.appending(path: "rates-\(region.rawValue).json")
    }

    static func save(_ rates: [Rate], region: Region) {
        guard let url = url(region: region) else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(rates) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func load(region: Region) -> [Rate] {
        guard let url = url(region: region), let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return ((try? decoder.decode([Rate].self, from: data)) ?? []).normalised()
    }
}
