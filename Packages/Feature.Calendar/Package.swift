// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Feature.Calendar",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Feature_Calendar", targets: ["Feature_Calendar"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI"),
        .package(path: "../WorkspaceUI")
    ],
    targets: [
        .target(
            name: "Feature_Calendar",
            dependencies: ["Core", "Data", "SharedUI", "WorkspaceUI"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "Feature_CalendarTests",
            dependencies: ["Feature_Calendar", "Core", "Data"],
            swiftSettings: strictConcurrencySettings
        ),
    ]
)
