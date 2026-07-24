// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "WorkspaceUI",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "WorkspaceUI", targets: ["WorkspaceUI"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI"),
    ],
    targets: [
        .target(
            name: "WorkspaceUI",
            dependencies: ["Core", "Data", "SharedUI"],
            swiftSettings: strictConcurrencySettings
        ),
    ]
)
