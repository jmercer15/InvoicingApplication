// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Feature.NDIS",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Feature_NDIS", targets: ["Feature_NDIS"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(
            name: "Feature_NDIS",
            dependencies: ["Core", "Data", "SharedUI"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "Feature_NDISTests",
            dependencies: ["Feature_NDIS", "Core"],
            swiftSettings: strictConcurrencySettings
        )
    ]
)
