// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Feature.Settings",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Feature_Settings", targets: ["Feature_Settings"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI"),
        .package(path: "../WorkspaceUI")
    ],
    targets: [
        .target(
            name: "Feature_Settings",
            dependencies: ["Core", "Data", "SharedUI", "WorkspaceUI"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "Feature_SettingsTests",
            dependencies: ["Feature_Settings", "Core", "Data", "SharedUI", "WorkspaceUI"],
            path: "Tests/Feature_SettingsTests",
            swiftSettings: strictConcurrencySettings
        )
    ]
)
