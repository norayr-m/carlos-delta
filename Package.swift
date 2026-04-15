// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "carlos-delta",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "Savanna",
            path: "Sources/Savanna",
            resources: [.process("Shaders")]
        ),
        .executableTarget(
            name: "savanna-cli",
            dependencies: ["Savanna"],
            path: "Sources/SavannaCLI"
        ),
        .executableTarget(
            name: "savanna-play",
            dependencies: ["Savanna"],
            path: "Sources/SavannaPlay"
        ),
    ]
)
