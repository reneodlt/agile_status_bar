import SwiftUI

struct PopoverView: View {
    @ObservedObject var store: RatesStore
    @ObservedObject var settings: Settings
    @State private var showingSettings = false

    private static let cardWidth: CGFloat = 340

    /// The card turns about its vertical axis. Spring rather than ease so it
    /// settles with a little weight instead of stopping dead.
    private var turn: Animation { .spring(response: 0.55, dampingFraction: 0.86) }

    /// Faces swap exactly edge-on — an instantaneous cut at the halfway point,
    /// so the two sides never cross-fade through each other.
    private var faceSwap: Animation { .linear(duration: 0.01).delay(0.175) }

    var body: some View {
        ZStack {
            face(front: true) { priceFace }
            face(front: false) { settingsFace }
        }
        .frame(width: Self.cardWidth)
    }

    // MARK: - Card flip

    private func face<Content: View>(front: Bool,
                                     @ViewBuilder content: () -> Content) -> some View {
        let hidden = front ? showingSettings : !showingSettings
        // The reverse face starts pre-rotated so its content reads the right
        // way round when it arrives, rather than mirrored.
        let angle: Double = front ? (showingSettings ? 180 : 0)
                                  : (showingSettings ? 0 : -180)

        return content()
            .background(.regularMaterial)
            // Shallow perspective on purpose: the popover clips to its own
            // bounds, and a deeper projection would push the near edge of the
            // card outside them mid-turn.
            .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0), perspective: 0.25)
            .animation(turn, value: showingSettings)
            .opacity(hidden ? 0 : 1)
            .animation(faceSwap, value: showingSettings)
            .allowsHitTesting(!hidden)
            .accessibilityHidden(hidden)
    }

    private func flip() {
        showingSettings.toggle()
    }

    // MARK: - Front: prices

    private var priceFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(title: "Agile Octopus",
                       subtitle: settings.region.name,
                       symbol: "gearshape",
                       hint: "Settings")
            Divider()
            main
                .frame(maxHeight: .infinity, alignment: .top)
            Divider()
            priceFooter
        }
    }

    private var settingsFace: some View {
        VStack(alignment: .leading, spacing: 0) {
            cardHeader(title: "Settings",
                       subtitle: nil,
                       symbol: "chevron.left",
                       hint: "Back to prices")
            Divider()
            SettingsPane(settings: settings, store: store)
                .frame(maxHeight: .infinity, alignment: .top)
            Divider()
            settingsFooter
        }
    }

    // MARK: - Header

    private func cardHeader(title: String, subtitle: String?,
                            symbol: String, hint: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.horizontal.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button(action: flip) {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(hint)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Main

    @ViewBuilder
    private var main: some View {
        VStack(alignment: .leading, spacing: 14) {
            hero
            if !store.window.isEmpty {
                PriceChartView(rates: store.window,
                               values: store.windowValues,
                               now: store.now,
                               vatIncluded: settings.includeVAT)
                stats
            } else if case .failed(let reason) = store.state {
                notice(reason, symbol: "exclamationmark.triangle")
            } else {
                notice("Fetching prices…", symbol: "clock")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func notice(_ text: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
            Text(text)
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
    }

    // MARK: - Hero

    @ViewBuilder
    private var hero: some View {
        if let current = store.currentRate {
            let band = store.band(for: current)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Fmt.pence(store.price(current), decimals: 2))
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("/kWh")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    bandChip(band)
                }
                HStack(spacing: 5) {
                    Text(band.verdict)
                    Text("·").foregroundStyle(.tertiary)
                    Text("\(Fmt.relative(current.end, now: store.now)) left")
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if let next = store.nextRate {
                    nextRow(next, current: current)
                        .padding(.top, 7)
                }
            }
        } else {
            notice("No price for the current half hour.", symbol: "questionmark.circle")
        }
    }

    private func bandChip(_ band: PriceBand) -> some View {
        HStack(spacing: 4) {
            Image(systemName: band.symbolName)
                .font(.system(size: 10, weight: .semibold))
            Text(band.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(band.color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(band.color.opacity(0.14), in: Capsule())
    }

    private func nextRow(_ next: Rate, current: Rate) -> some View {
        let delta = next.valueIncVat - current.valueIncVat
        let rising = delta >= 0
        return HStack(spacing: 6) {
            Text("Next")
                .foregroundStyle(.secondary)
            Text(Fmt.slotTime.string(from: next.validFrom))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Spacer(minLength: 0)
            Image(systemName: rising ? "arrow.up" : "arrow.down")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(store.band(for: next).color)
            Text(Fmt.signedPence(delta))
                .foregroundStyle(.secondary)
                .monospacedDigit()
            Text(Fmt.pence(store.price(next), decimals: 2))
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.system(size: 11))
    }

    // MARK: - Stats

    @ViewBuilder
    private var stats: some View {
        VStack(spacing: 0) {
            if let cheapest = store.cheapest {
                statRow(icon: "arrow.down.circle.fill",
                        tint: PriceBand.cheapest.color,
                        title: "Cheapest",
                        detail: Fmt.range(cheapest.validFrom, cheapest.end, now: store.now),
                        value: Fmt.pence(store.price(cheapest), decimals: 2))
            }
            if let priciest = store.priciest {
                Divider().padding(.vertical, 6)
                statRow(icon: "arrow.up.circle.fill",
                        tint: PriceBand.priciest.color,
                        title: "Priciest",
                        detail: Fmt.range(priciest.validFrom, priciest.end, now: store.now),
                        value: Fmt.pence(store.price(priciest), decimals: 2))
            }
            if let average = store.displayAverage {
                Divider().padding(.vertical, 6)
                statRow(icon: "equal.circle.fill",
                        tint: PriceBand.typical.color,
                        title: "Average",
                        detail: horizonCaption,
                        value: Fmt.pence(average, decimals: 2))
            }
            if let best = store.cheapestWindow(hours: 2) {
                Divider().padding(.vertical, 6)
                statRow(icon: "washer.fill",
                        tint: PriceBand.cheap.color,
                        title: "Best 2 hours",
                        detail: Fmt.range(best.start, best.end, now: store.now),
                        value: Fmt.pence(best.averagePence, decimals: 2))
            }
        }
    }

    /// Says how much of the 24h ahead is actually published — Agile only
    /// releases the next day around 16:00, so before then the horizon is short.
    private var horizonCaption: String {
        store.coversFullHorizon ? "next 24 hours" : "next \(Fmt.duration(coverageAhead))"
    }

    private var coverageAhead: TimeInterval {
        guard let end = store.coverageEnd else { return 0 }
        return max(end.timeIntervalSince(store.now), 0)
    }

    private func statRow(icon: String, tint: Color, title: String,
                         detail: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(tint)
                .frame(width: 15)
            Text(title)
                .font(.system(size: 12))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .monospacedDigit()
        }
    }

    // MARK: - Footers

    private var priceFooter: some View {
        HStack(spacing: 8) {
            statusText
            Spacer(minLength: 4)
            Button("Refresh") { store.refresh() }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Text("·").foregroundStyle(.tertiary)
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var settingsFooter: some View {
        HStack(spacing: 8) {
            Text("Agile Bar \(Self.version)")
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Button("Done", action: flip)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    @ViewBuilder
    private var statusText: some View {
        switch store.state {
        case .loading:
            HStack(spacing: 5) {
                ProgressView().controlSize(.small).scaleEffect(0.7)
                Text("Updating…").foregroundStyle(.secondary)
            }
        case .failed(let message):
            HStack(spacing: 4) {
                Image(systemName: "wifi.exclamationmark")
                Text(store.rates.isEmpty ? "Offline" : "Showing cached prices")
            }
            .foregroundStyle(.secondary)
            .help(message)
        default:
            if let updated = store.lastUpdated {
                Text("Updated \(Fmt.slotTime.string(from: updated))")
                    .foregroundStyle(.secondary)
            } else {
                Text("Prices from Octopus Energy")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
