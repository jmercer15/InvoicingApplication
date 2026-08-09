// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Feature.BillingHub",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "Feature_BillingHub", targets: ["Feature_BillingHub"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../PersistenceModels"),
        .package(path: "../Data"),
        .package(path: "../DataInterfaces"),
        .package(path: "../SharedUI"),
        .package(path: "../WorkspaceUI"),
        .package(path: "../Feature.InvoiceTemplateEditor")
    ],
    targets: [
        .target(
            name: "Feature_BillingHub",
            dependencies: [
                "Core",
                "PersistenceModels", "DataInterfaces", "SharedUI", "WorkspaceUI", .product(name: "InvoiceTableLayoutEditor", package: "Feature.InvoiceTemplateEditor")],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "Feature_BillingHubTests",
            dependencies: [
                "Feature_BillingHub",
                "Core",
                "Data",
                "SharedUI"
            ],
            swiftSettings: strictConcurrencySettings
        )
    ]
)
