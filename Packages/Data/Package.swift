// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.macOS("26.1")],
    products: [
        .library(name: "Data", targets: ["Data"])
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(url: "https://github.com/CoreOffice/CoreXLSX.git", from: "0.14.0")
    ],
    targets: [
        .target(
            name: "Data", 
            dependencies: [
                "Core",
                .product(name: "CoreXLSX", package: "CoreXLSX")
            ],
            exclude: [
                "Mapping/TravelCharge_Architectural_Analysis.md",
                "Mapping/Property_Usage_Audit_Report.md",
                "Mapping/Troubleshooting_Guide.md",
                "Mapping/Architectural_Patterns_and_Conventions.md",
                "Mapping/Entity_Relationship_Diagram_Updates.md",
                "Mapping/Relationship_Delete_Rules_Audit.md",
                "Mapping/Data_Migration_Strategy.md",
                "Documentation/NDIS_Price_Handling_Migration.md"
            ]
        ),
        .testTarget(
            name: "DataUseCaseTests",
            dependencies: ["Data", "Core"],
            path: "Tests/DataTests/UseCases"
        )
    ]
)
