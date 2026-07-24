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
    ],
    targets: [
        .target(
            name: "DataInterfaces",
            dependencies: ["Core"],
            path: "Sources/DataInterfaces",
            swiftSettings: strictConcurrencySettings
        )
    ]
)

