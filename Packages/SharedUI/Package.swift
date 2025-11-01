// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "SharedUI",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "SharedUI", targets: ["SharedUI"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data")
    ],
    targets: [
        .target(
            name: "SharedUI",
            dependencies: ["Core", "Data"],
            resources: [
                .process("Assets")
            ]
        )
    ]
)
