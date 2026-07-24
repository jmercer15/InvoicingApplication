// swift-tools-version: 6.2
import PackageDescription

private let strictConcurrencySettings: [SwiftSetting] = [
    .enableExperimentalFeature("StrictConcurrency"),
]

let package = Package(
    name: "Feature.InvoiceTemplateEditor",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "InvoiceTableLayoutEditor", targets: ["InvoiceTableLayoutEditor"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data")
    ],
    targets: [
        .target(
            name: "InvoiceTableLayoutEditor",
            dependencies: ["Core"],
            swiftSettings: strictConcurrencySettings
        ),
        .testTarget(
            name: "InvoiceTableLayoutEditorTests",
            dependencies: ["InvoiceTableLayoutEditor", "Core", "Data"],
            swiftSettings: strictConcurrencySettings
        )
    ]
)
