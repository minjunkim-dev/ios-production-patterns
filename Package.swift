// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ProductionReliability",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(name: "ProductionReliability", targets: ["ProductionReliability"]),
    ],
    targets: [
        .target(name: "ProductionReliability"),
        .testTarget(
            name: "ProductionReliabilityTests",
            dependencies: ["ProductionReliability"]
        ),
    ]
)
