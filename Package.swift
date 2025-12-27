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
        .library(
            name: "SpacetimeDBCodegenLib",
            targets: ["SpacetimeDBCodegenLib"]
        ),
        .executable(
            name: "spacetimedb-codegen",
            targets: ["SpacetimeDBCodegen"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "SpacetimeDB",
            path: "Sources/SpacetimeDB"
        ),
        .target(
            name: "SpacetimeDBCodegenLib",
            dependencies: [],
            path: "Sources/SpacetimeDBCodegenLib"
        ),
        .executableTarget(
            name: "SpacetimeDBCodegen",
            dependencies: [
                "SpacetimeDBCodegenLib",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/SpacetimeDBCodegen"
        ),
        .testTarget(
            name: "SpacetimeDBTests",
            dependencies: ["SpacetimeDB"],
            path: "Tests/SpacetimeDBTests"
        ),
        .testTarget(
            name: "SpacetimeDBCodegenTests",
            dependencies: ["SpacetimeDBCodegenLib"],
            path: "Tests/SpacetimeDBCodegenTests"
        ),
    ]
)
