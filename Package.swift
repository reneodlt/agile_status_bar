// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "OctoStatusBar",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OctoStatusBar",
            path: "Sources/OctoStatusBar",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
