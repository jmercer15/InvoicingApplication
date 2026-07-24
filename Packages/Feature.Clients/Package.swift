// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Feature.Clients",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Feature_Clients", targets: ["Feature_Clients"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI"),
        .package(path: "../WorkspaceUI")
    ],
    targets: [
        .target(
            name: "Feature_Clients",
            dependencies: ["Core", "Data", "SharedUI", "WorkspaceUI"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "Feature_ClientsTests",
            dependencies: ["Feature_Clients", "Core", "Data", "SharedUI", "WorkspaceUI"],
            swiftSettings: strictConcurrencySettings
        )
    ]
)
