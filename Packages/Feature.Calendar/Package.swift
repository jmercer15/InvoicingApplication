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
        .package(path: "../PersistenceModels"),
        .package(path: "../Data"),
        .package(path: "../DataInterfaces"),
        .package(path: "../SharedUI"),
        .package(path: "../WorkspaceUI")
    ],
    targets: [
        .target(
            name: "Feature_Calendar",
            dependencies: [
                "Core",
                "PersistenceModels", "Data", "DataInterfaces", "SharedUI", "WorkspaceUI"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "Feature_CalendarTests",
            dependencies: ["Feature_Calendar", "Core", .product(name: "CoreTesting", package: "Core"), "Data"],
            swiftSettings: strictConcurrencySettings
        ),
    ]
)
