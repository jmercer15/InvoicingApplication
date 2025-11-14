// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.Invoices",
    platforms: [.macOS("26.1")],
    products: [
        .library(name: "Feature_Invoices", targets: ["Feature_Invoices"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(name: "Feature_Invoices", dependencies: ["Core", "Data", "SharedUI"])
    ]
)
