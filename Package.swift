// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "carlos-delta",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "simulate", path: "Sources/Simulate"),
        .executableTarget(name: "playback", path: "Sources/Playback"),
    ]
)
