// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "TerminalKit",
    platforms: [.macOS(.v26)],
    products: [.library(name: "TerminalKit", targets: ["TerminalKit"])],
    targets: [
        .binaryTarget(name: "GhosttyKit", path: "Vendor/GhosttyKit.xcframework"),
        .target(
            name: "TerminalKit",
            dependencies: ["GhosttyKit"],
            resources: [.copy("Resources/ghostty"), .copy("Resources/terminfo"),
                        .copy("Resources/RelayLight"), .copy("Resources/RelayDark")],
            linkerSettings: [.linkedLibrary("c++"), .linkedFramework("Carbon"),
                             .linkedFramework("Metal"), .linkedFramework("QuartzCore")]
        ),
        .testTarget(name: "TerminalKitTests", dependencies: ["TerminalKit"])
    ]
)
