// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LightCompressor",
    platforms: [
        .iOS(.v14), .tvOS(.v14)
    ],
    products: [
        .library(
            name: "LightCompressor",
            targets: ["LightCompressor"]),
    ],
    targets: [
        .target(
            name: "LightCompressor",
            path: "Sources/LightCompressor"
        ),
        .testTarget(
            name: "LightCompressorTests",
            dependencies: ["LightCompressor"],
            path: "Sources/Tests"
        ),
    ]
)
