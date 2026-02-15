// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.BillingHub",
    platforms: [.macOS("26.1")],
    products: [
        .library(name: "Feature_BillingHub", targets: ["Feature_BillingHub"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(name: "Feature_BillingHub", dependencies: ["Core", "Data", "SharedUI"]),
        .testTarget(
            name: "Feature_BillingHubTests",
            dependencies: ["Feature_BillingHub", "Core", "Data"]
        )
    ]
)
