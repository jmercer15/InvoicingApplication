// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Data",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Data", targets: ["Data"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../DataInterfaces"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.0")
    ],
    targets: [
        .target(
            name: "Data", 
            dependencies: [
                "Core",
                "DataInterfaces",
                .product(name: "CoreXLSX", package: "CoreXLSX")
            ],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "DataUseCaseTests",
            dependencies: ["Data", "Core"],
            path: "Tests/DataTests/UseCases",
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "DataServiceTests",
            dependencies: ["Data", "Core"],
            path: "Tests/DataTests/Services",
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "DataBusinessLogicTests",
            dependencies: ["Data", "Core"],
            path: "Tests/DataTests/BusinessLogic",
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "DataValidationTests",
            dependencies: ["Data", "Core"],
            path: "Tests/DataTests/Validation",
            swiftSettings: strictConcurrencySettings
        )
    ]
)
