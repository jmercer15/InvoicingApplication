// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.Settings",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Feature_Settings", targets: ["Feature_Settings"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.1")
    ],
    targets: [
        .target(name: "Feature_Settings", dependencies: ["Core", "Data", "SharedUI", .product(name: "CoreXLSX", package: "CoreXLSX")])
    ]
)
