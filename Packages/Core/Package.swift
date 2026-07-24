// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Core",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Core", targets: ["Core"])
    ],
    targets: [
        .target(
            name: "Core",
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "CoreTests",
            dependencies: ["Core"],
            swiftSettings: strictConcurrencySettings
        )
    ]
)
