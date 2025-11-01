// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.Calendar",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Feature_Calendar", targets: ["Feature_Calendar"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(name: "Feature_Calendar", dependencies: ["Core", "Data", "SharedUI"])
    ]
)
