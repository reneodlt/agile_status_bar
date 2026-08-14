import SwiftUI
import ServiceManagement

struct SettingsPane: View {
    @ObservedObject var settings: Settings
    @ObservedObject var store: RatesStore

    @State private var postcode = ""
    @State private var lookupState: LookupState = .idle
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    private enum LookupState: Equatable {
        case idle, working
        case found(Region)
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            regionSection
            Divider()
            displaySection
            Divider()
            aboutSection
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Region

    private var regionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REGION")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.5)

            Picker("", selection: $settings.region) {
                ForEach(Region.allCases) { region in
                    Text(region.label).tag(region)
                }
            }
            .labelsHidden()
            .controlSize(.small)

            HStack(spacing: 6) {
                TextField("Or enter a postcode", text: $postcode)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .onSubmit(lookup)
                Button("Find", action: lookup)
                    .controlSize(.small)
                    .disabled(postcode.isEmpty || lookupState == .working)
            }

            switch lookupState {
            case .working:
                caption("Looking up…", tint: .secondary)
            case .found(let region):
                caption("Matched region \(region.rawValue) — \(region.name)", tint: .secondary)
            case .failed(let message):
                caption(message, tint: .secondary)
            case .idle:
                caption("Agile prices differ by grid region.", tint: .tertiary)
            }
        }
    }

    private func caption(_ text: String, tint: HierarchicalShapeStyle) -> some View {
        Text(text)
            .font(.system(size: 10))
            .foregroundStyle(tint)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func lookup() {
        let entered = postcode
        guard !entered.isEmpty else { return }
        lookupState = .working
        Task {
            do {
                let region = try await OctopusAPI().region(forPostcode: entered)
                settings.region = region
                lookupState = .found(region)
            } catch {
                lookupState = .failed(error.localizedDescription)
            }
        }
    }

    // MARK: - Display

    private var displaySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DISPLAY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .kerning(0.5)

            Toggle("Include VAT in prices", isOn: $settings.includeVAT)
            Toggle("Colour the menu bar dot", isOn: $settings.colourMenuBar)
            Toggle("Show “p” after the price", isOn: $settings.showPenceSuffix)
            Toggle("Open at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enabled in
                    setLaunchAtLogin(enabled)
                }
        }
        .toggleStyle(.checkbox)
        .font(.system(size: 12))
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Registration fails when running unbundled (e.g. `swift run`);
            // reflect reality rather than leaving the toggle lying.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            referralRow
            Text("Prices come from the Octopus Energy public API. No account details are needed or collected.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Not affiliated with or endorsed by Octopus Energy.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    /// Tucked away on the settings face rather than beside the prices: it is
    /// an aside, not the point of the app. The developer's benefit is stated
    /// outright — an undisclosed referral link would be a dark pattern.
    private var referralRow: some View {
        Link(destination: Self.referralURL) {
            HStack(spacing: 7) {
                Image(systemName: "gift")
                    .font(.system(size: 12))
                    .foregroundStyle(PriceBand.cheap.color)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Not on Octopus yet?")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                    Text("Referral link — credits you and the developer alike.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(PriceBand.cheap.color.opacity(0.10),
                        in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help("Opens share.octopus.energy in your browser")
    }

    private static let referralURL = URL(string: "https://share.octopus.energy/furious-jay-669")!
}
