import SwiftUI

/// Half-hourly unit rates across the forecast horizon.
///
/// Bars are anchored to a **zero baseline** rather than a floating minimum:
/// with Agile, "below zero" is a real state (plunge pricing pays you to
/// consume), so the axis crossing carries meaning and must not be cropped away.
struct PriceChartView: View {
    let rates: [Rate]
    let values: [Double]
    let now: Date
    let vatIncluded: Bool

    @State private var hoverIndex: Int?

    private let barGap: CGFloat = 2
    private let plotHeight: CGFloat = 74

    private var maxValue: Double { max(values.max() ?? 0, 0) }
    private var minValue: Double { min(values.min() ?? 0, 0) }
    private var span: Double { max(maxValue - minValue, 0.001) }
    /// Share of the plot above the zero line.
    private var zeroFraction: CGFloat { CGFloat(maxValue / span) }

    private var cheapestIndex: Int? {
        values.indices.min { values[$0] < values[$1] }
    }

    private var priciestIndex: Int? {
        values.indices.max { values[$0] < values[$1] }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            calloutRow
            plot
            axisRow
        }
    }

    // MARK: - Callout

    /// One line that doubles as hover readout and, at rest, as the direct
    /// label for the two slots that matter. Labelling every bar would be noise
    /// at this width.
    private var calloutRow: some View {
        Group {
            if let index = hoverIndex, rates.indices.contains(index) {
                let rate = rates[index]
                let band = PriceBand.band(for: rate.valueIncVat, in: values)
                HStack(spacing: 6) {
                    Circle().fill(band.color).frame(width: 7, height: 7)
                    Text(Fmt.range(rate.validFrom, rate.end, now: now))
                        .foregroundStyle(.secondary)
                    Text(Fmt.pence(vatIncluded ? rate.valueIncVat : rate.valueExcVat, decimals: 2))
                        .fontWeight(.semibold)
                        .monospacedDigit()
                    Text(band.label).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 6) {
                    Text("Next \(coverageLabel)")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text("hover for detail")
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .font(.system(size: 11))
        .lineLimit(1)
        .frame(height: 14)
    }

    private var coverageLabel: String {
        guard let last = rates.last else { return "—" }
        return Fmt.duration(last.end.timeIntervalSince(now))
    }

    // MARK: - Plot

    private var plot: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let count = max(rates.count, 1)
            let slot = width / CGFloat(count)
            let barWidth = max(slot - barGap, 1.5)
            let aboveHeight = plotHeight * zeroFraction

            ZStack(alignment: .topLeading) {
                // Zero line — only drawn when negative prices put it in play.
                if minValue < 0 {
                    Rectangle()
                        .fill(Color.primary.opacity(0.25))
                        .frame(height: 1)
                        .offset(y: aboveHeight)
                }

                HStack(alignment: .top, spacing: barGap) {
                    ForEach(Array(rates.enumerated()), id: \.element.id) { index, rate in
                        bar(for: rate,
                            index: index,
                            width: barWidth,
                            aboveHeight: aboveHeight)
                    }
                }
            }
            .frame(width: width, height: plotHeight, alignment: .topLeading)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let point):
                    let index = Int(point.x / max(slot, 0.001))
                    hoverIndex = rates.indices.contains(index) ? index : nil
                case .ended:
                    hoverIndex = nil
                }
            }
        }
        .frame(height: plotHeight)
    }

    private func bar(for rate: Rate, index: Int, width: CGFloat, aboveHeight: CGFloat) -> some View {
        let value = rate.valueIncVat
        let band = PriceBand.band(for: value, in: values)
        let magnitude = CGFloat(abs(value) / span) * plotHeight
        let isHovered = hoverIndex == index
        let isMarked = index == cheapestIndex || index == priciestIndex
        let isNow = rate.contains(now)

        let length = max(magnitude, 1.5)

        return ZStack {
            // "You are here" reads better as a column wash than as another
            // floating mark competing with the extremes.
            if isNow {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.primary.opacity(0.12))
            }

            VStack(spacing: 0) {
                // Above the zero line: bars grow upward from the baseline.
                ZStack(alignment: .bottom) {
                    Color.clear
                    if value >= 0 {
                        UnevenRoundedRectangle(topLeadingRadius: 2, topTrailingRadius: 2)
                            .fill(band.color)
                            .frame(height: length)
                        // Anchored to the bar's own tip — pinned to the top of
                        // the plot it would float free of the bar it labels.
                        if isMarked { marker.padding(.bottom, length + 3) }
                    }
                }
                .frame(height: aboveHeight)

                // Below the zero line: plunge prices grow downward.
                ZStack(alignment: .top) {
                    Color.clear
                    if value < 0 {
                        UnevenRoundedRectangle(bottomLeadingRadius: 2, bottomTrailingRadius: 2)
                            .fill(band.color)
                            .frame(height: length)
                        if isMarked { marker.padding(.top, length + 3) }
                    }
                }
                .frame(height: plotHeight - aboveHeight)
            }
        }
        .frame(width: width)
        .opacity(hoverIndex == nil || isHovered ? 1 : 0.45)
    }

    /// Secondary encoding for the cheapest and priciest slots, so the extremes
    /// stay findable without relying on colour alone.
    private var marker: some View {
        Circle()
            .fill(Color.primary.opacity(0.6))
            .frame(width: 3, height: 3)
    }

    // MARK: - Axis

    private var axisRow: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let count = max(rates.count, 1)
            ZStack(alignment: .topLeading) {
                ForEach(tickIndices(count: count), id: \.self) { index in
                    Text(index == 0 ? "now" : Fmt.slotTime.string(from: rates[index].validFrom))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                        .offset(x: min(CGFloat(index) / CGFloat(count) * width, width - 26))
                }
            }
        }
        .frame(height: 11)
    }

    /// A tick every six hours, plus "now".
    private func tickIndices(count: Int) -> [Int] {
        guard count > 0 else { return [] }
        return stride(from: 0, to: count, by: 12).map { $0 }
    }
}
