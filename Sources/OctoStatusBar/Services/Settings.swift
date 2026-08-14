import Foundation
import Combine

/// User preferences, persisted in the app's sandboxed defaults.
final class Settings: ObservableObject {
    static let shared = Settings()

    private enum Key {
        static let region = "region"
        static let showPenceSuffix = "showPenceSuffix"
        static let colourMenuBar = "colourMenuBar"
        static let includeVAT = "includeVAT"
        static let hasCompletedSetup = "hasCompletedSetup"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.region: Region.c.rawValue,
            Key.showPenceSuffix: true,
            Key.colourMenuBar: true,
            Key.includeVAT: true,
            Key.hasCompletedSetup: false,
        ])
        region = Region(rawValue: defaults.string(forKey: Key.region) ?? "C") ?? .c
        showPenceSuffix = defaults.bool(forKey: Key.showPenceSuffix)
        colourMenuBar = defaults.bool(forKey: Key.colourMenuBar)
        includeVAT = defaults.bool(forKey: Key.includeVAT)
        hasCompletedSetup = defaults.bool(forKey: Key.hasCompletedSetup)
    }

    @Published var region: Region { didSet { defaults.set(region.rawValue, forKey: Key.region) } }
    @Published var showPenceSuffix: Bool { didSet { defaults.set(showPenceSuffix, forKey: Key.showPenceSuffix) } }
    @Published var colourMenuBar: Bool { didSet { defaults.set(colourMenuBar, forKey: Key.colourMenuBar) } }
    @Published var includeVAT: Bool { didSet { defaults.set(includeVAT, forKey: Key.includeVAT) } }
    @Published var hasCompletedSetup: Bool { didSet { defaults.set(hasCompletedSetup, forKey: Key.hasCompletedSetup) } }
}
