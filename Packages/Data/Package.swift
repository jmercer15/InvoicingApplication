// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Data",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Data", targets: ["Data"])
    ],
    dependencies: [
        .package(path: "../Core")
    ],
    targets: [
        .target(
            name: "Data", 
            dependencies: ["Core"],
            exclude: [
                "Monitoring/AlertingDocumentation.md",
                "Monitoring/MonitoringDocumentation.md",
                "Mapping/TravelCharge_Architectural_Analysis.md",
                "Monitoring/IntegrityMetricsDocumentation.md",
                "Mapping/Property_Usage_Audit_Report.md",
                "Mapping/Troubleshooting_Guide.md",
                "Mapping/Architectural_Patterns_and_Conventions.md",
                "Mapping/Entity_Relationship_Diagram_Updates.md",
                "Mapping/Relationship_Delete_Rules_Audit.md",
                "Mapping/Data_Migration_Strategy.md",
                "Documentation/NDIS_Price_Handling_Migration.md"
            ]
        )
    ]
)
