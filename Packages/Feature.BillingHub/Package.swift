// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Feature.BillingHub",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Feature_BillingHub", targets: ["Feature_BillingHub"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI"),
        .package(path: "../WorkspaceUI")
    ],
    targets: [
        .target(
            name: "Feature_BillingHub",
            dependencies: ["Core", "Data", "SharedUI", "WorkspaceUI"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "Feature_BillingHubTests",
            dependencies: [
                "Feature_BillingHub",
                "Core",
                "Data"
            ],
            swiftSettings: strictConcurrencySettings
        )
    ]
)
