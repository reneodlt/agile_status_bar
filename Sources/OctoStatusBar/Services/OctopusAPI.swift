import Foundation

enum OctopusAPIError: LocalizedError {
    case badResponse(status: Int)
    case noAgileProduct
    case unknownPostcode

    var errorDescription: String? {
        switch self {
        case .badResponse(let status): "Octopus API returned HTTP \(status)."
        case .noAgileProduct: "Couldn't find a current Agile tariff."
        case .unknownPostcode: "No grid region found for that postcode."
        }
    }
}

/// Read-only client for Octopus Energy's public tariff endpoints.
///
/// Everything used here is unauthenticated public pricing data — the app never
/// asks for, stores, or transmits an account number or API key.
struct OctopusAPI {
    static let base = URL(string: "https://api.octopus.energy/v1")!

    /// Used only if product discovery fails (e.g. offline on first run).
    static let fallbackProductCode = "AGILE-24-10-01"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Requests

    private func get<T: Decodable>(_ url: URL, as: T.Type) async throws -> T {
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OctopusAPIError.badResponse(status: -1)
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OctopusAPIError.badResponse(status: http.statusCode)
        }
        return try Self.decoder.decode(T.self, from: data)
    }

    static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let raw = try decoder.singleValueContainer().decode(String.self)
            if let date = iso8601Fractional.date(from: raw) ?? iso8601Plain.date(from: raw) {
                return date
            }
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Unparseable date \(raw)"))
        }
        return d
    }()

    private static let iso8601Fractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso8601Plain = ISO8601DateFormatter()

    // MARK: - Product discovery

    private struct ProductList: Decodable {
        struct Product: Decodable {
            let code: String
            let direction: String
            let brand: String?
            let availableFrom: Date?
            let availableTo: Date?

            enum CodingKeys: String, CodingKey {
                case code, direction, brand
                case availableFrom = "available_from"
                case availableTo = "available_to"
            }
        }
        let results: [Product]
    }

    /// Finds the Agile import product currently on sale.
    ///
    /// Octopus periodically supersedes Agile (…-22-07-22 → …-24-10-01 → …), so
    /// resolving it at runtime keeps the app working across those rollovers
    /// without a release.
    func currentAgileProductCode(now: Date = Date()) async throws -> String {
        let url = Self.base.appending(path: "products/")
            .appending(queryItems: [
                .init(name: "brand", value: "OCTOPUS_ENERGY"),
                .init(name: "page_size", value: "100"),
            ])

        let list = try await get(url, as: ProductList.self)
        let candidates = list.results.filter {
            $0.code.hasPrefix("AGILE")
                && !$0.code.contains("OUTGOING")
                && $0.direction.uppercased() == "IMPORT"
                && ($0.availableFrom ?? .distantPast) <= now
                && ($0.availableTo ?? .distantFuture) > now
        }

        guard let newest = candidates.max(by: {
            ($0.availableFrom ?? .distantPast) < ($1.availableFrom ?? .distantPast)
        }) else {
            throw OctopusAPIError.noAgileProduct
        }
        return newest.code
    }

    // MARK: - Rates

    private struct RatePage: Decodable {
        let next: URL?
        let results: [Rate]
    }

    /// Unit rates for `region`, covering `from`…`to`. Follows pagination, but
    /// stops after a handful of pages so a bad `next` chain can't spin forever.
    func rates(productCode: String,
               region: Region,
               from: Date,
               to: Date) async throws -> [Rate] {
        let tariff = "E-1R-\(productCode)-\(region.rawValue)"
        var url: URL? = Self.base
            .appending(path: "products/\(productCode)/electricity-tariffs/\(tariff)/standard-unit-rates/")
            .appending(queryItems: [
                .init(name: "period_from", value: Self.iso8601Plain.string(from: from)),
                .init(name: "period_to", value: Self.iso8601Plain.string(from: to)),
                .init(name: "page_size", value: "200"),
            ])

        var collected: [Rate] = []
        var pages = 0
        while let next = url, pages < 5 {
            let page = try await get(next, as: RatePage.self)
            collected.append(contentsOf: page.results)
            url = page.next
            pages += 1
        }
        return collected.normalised()
    }

    // MARK: - Region lookup

    private struct GSPList: Decodable {
        struct Point: Decodable {
            let groupID: String
            enum CodingKeys: String, CodingKey { case groupID = "group_id" }
        }
        let results: [Point]
    }

    /// Maps a UK postcode to its grid supply point so users don't have to know
    /// their DNO letter.
    func region(forPostcode postcode: String) async throws -> Region {
        let cleaned = postcode.uppercased().filter { $0.isLetter || $0.isNumber }
        guard !cleaned.isEmpty else { throw OctopusAPIError.unknownPostcode }

        let url = Self.base.appending(path: "industry/grid-supply-points/")
            .appending(queryItems: [.init(name: "postcode", value: cleaned)])

        let list = try await get(url, as: GSPList.self)
        guard let first = list.results.first, let region = Region(groupID: first.groupID) else {
            throw OctopusAPIError.unknownPostcode
        }
        return region
    }
}
