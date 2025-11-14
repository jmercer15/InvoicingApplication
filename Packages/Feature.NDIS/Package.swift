// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.NDIS",
    platforms: [.macOS("26.1")],
    products: [
        .library(name: "Feature_NDIS", targets: ["Feature_NDIS"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(
            name: "Feature_NDIS",
            dependencies: ["Core", "Data", "SharedUI"]
        )
    ]
)
