// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.Settings",
    platforms: [.macOS("26.1")],
    products: [
        .library(name: "Feature_Settings", targets: ["Feature_Settings"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(name: "Feature_Settings", dependencies: ["Core", "Data", "SharedUI"])
    ]
)
