// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.Clients",
    platforms: [.macOS("26.1")],
    products: [
        .library(name: "Feature_Clients", targets: ["Feature_Clients"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(name: "Feature_Clients", dependencies: ["Core", "Data", "SharedUI"])
    ]
)
