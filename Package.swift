// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SpacetimeDB",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SpacetimeDB",
            targets: ["SpacetimeDB"]
        ),
    ],
    targets: [
        .target(
            name: "SpacetimeDB",
            path: "Sources/SpacetimeDB"
        ),
        .testTarget(
            name: "SpacetimeDBTests",
            dependencies: ["SpacetimeDB"],
            path: "Tests/SpacetimeDBTests"
        ),
    ]
)
