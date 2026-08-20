// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "SharedUI",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../PersistenceModels"),
    ],
    targets: [
        .target(
            name: "SharedUI",
            dependencies: ["Core", "PersistenceModels"],
            resources: [
                .process("Assets")
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "SharedUITests",
            dependencies: ["SharedUI", "Core", .product(name: "CoreTesting", package: "Core")],
            path: "Tests/SharedUITests",
            swiftSettings: strictConcurrencySettings
        )
    ]
)
