// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Feature.InvoiceTemplateEditor",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Feature_InvoiceTemplateEditor", targets: ["Feature_InvoiceTemplateEditor"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Data"),
        .package(path: "../SharedUI")
    ],
    targets: [
        .target(
            name: "Feature_InvoiceTemplateEditor",
            dependencies: ["Core", "Data", "SharedUI"]
        )
    ]
)
