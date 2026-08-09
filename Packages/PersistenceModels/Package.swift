// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "PersistenceModels",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "PersistenceModels", targets: ["PersistenceModels"])
    ],
    dependencies: [
        .package(path: "../Core"),
    ],
    targets: [
        .target(
            name: "PersistenceModels",
            dependencies: ["Core"],
            path: "Sources/PersistenceModels",
            swiftSettings: strictConcurrencySettings
        ),
    ]
)
