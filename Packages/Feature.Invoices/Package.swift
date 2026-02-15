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
        .package(path: "../SharedUI"),
        .package(path: "../Feature.InvoiceTemplateEditor")
    ],
    targets: [
        .target(
            name: "Feature_Invoices",
            dependencies: [
                "Core",
                "Data",
                "SharedUI",
                .product(name: "Feature_InvoiceTemplateEditor", package: "Feature.InvoiceTemplateEditor")
            ]
        ),
        .testTarget(
            name: "Feature_InvoicesTests",
            dependencies: [
                "Feature_Invoices",
                "Core",
                "Data",
                .product(name: "Feature_InvoiceTemplateEditor", package: "Feature.InvoiceTemplateEditor")
            ]
        )
    ]
)
