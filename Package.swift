// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ScreenOS",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // Core library — all shared types, engines, and managers.
        // Separate from the executable so XCTest can import it.
        .target(
            name: "ScreenOSKit",
            path: "Sources/ScreenOSKit"
        ),
        // Thin executable entry point. Only compiles main.swift;
        // the legacy files in this directory are kept for git history
        // but are excluded from compilation.
        .executableTarget(
            name: "ScreenOS",
            dependencies: ["ScreenOSKit"],
            path: "Sources/ScreenOS",
            sources: ["main.swift"]
        ),
        .testTarget(
            name: "ScreenOSTests",
            dependencies: ["ScreenOSKit"],
            path: "Tests/ScreenOSTests"
        )
    ]
)
