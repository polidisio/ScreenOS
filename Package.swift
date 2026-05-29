// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenOS",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ScreenOS",
            path: "Sources/ScreenOS"
        )
    ]
)
