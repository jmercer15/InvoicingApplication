// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "AppShell",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "AppShell", targets: ["AppShell"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../PersistenceModels"),
        .package(path: "../Data"),
        .package(path: "../DataInterfaces"),
        .package(path: "../SharedUI"),
        .package(path: "../WorkspaceUI"),
        .package(path: "../Feature.Settings"),
        .package(path: "../Feature.BillingHub"),
        .package(path: "../Feature.Calendar"),
        .package(path: "../Feature.NDIS"),
        .package(path: "../Feature.Clients"),
        .package(path: "../Feature.Invoices"),
        .package(path: "../Feature.InvoiceTemplateEditor"),
    ],
    targets: [
        .target(
            name: "AppShell",
            dependencies: [
                "Core",
                "PersistenceModels",
                "Data",
                "DataInterfaces",
                "SharedUI",
                "WorkspaceUI",
                .product(name: "Feature_Settings", package: "Feature.Settings"),
                .product(name: "Feature_BillingHub", package: "Feature.BillingHub"),
                .product(name: "Feature_Calendar", package: "Feature.Calendar"),
                .product(name: "Feature_NDIS", package: "Feature.NDIS"),
                .product(name: "Feature_Clients", package: "Feature.Clients"),
                .product(name: "Feature_Invoices", package: "Feature.Invoices"),
                .product(name: "InvoiceTableLayoutEditor", package: "Feature.InvoiceTemplateEditor"),
            ],
            path: "Sources/AppShell",
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: [
                "AppShell",
                "Core",
                .product(name: "CoreTesting", package: "Core"),
                "Data",
                "SharedUI",
                "WorkspaceUI",
                .product(name: "Feature_Settings", package: "Feature.Settings"),
                .product(name: "Feature_BillingHub", package: "Feature.BillingHub"),
                .product(name: "Feature_Calendar", package: "Feature.Calendar"),
                .product(name: "Feature_NDIS", package: "Feature.NDIS"),
                .product(name: "Feature_Clients", package: "Feature.Clients"),
                .product(name: "Feature_Invoices", package: "Feature.Invoices"),
                .product(name: "InvoiceTableLayoutEditor", package: "Feature.InvoiceTemplateEditor"),
            ],
            path: "Tests/AppShellTests",
            swiftSettings: strictConcurrencySettings
        ),
    ]
)
