// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "DataInterfaces",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "DataInterfaces", targets: ["DataInterfaces"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../PersistenceModels"),
    ],
    targets: [
        .target(
            name: "DataInterfaces",
            dependencies: ["Core", "PersistenceModels"],
            path: "Sources/DataInterfaces",
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "DataInterfacesTests",
            dependencies: ["DataInterfaces", "Core"],
            path: "Tests/DataInterfacesTests",
            swiftSettings: strictConcurrencySettings
        ),
    ]
)

