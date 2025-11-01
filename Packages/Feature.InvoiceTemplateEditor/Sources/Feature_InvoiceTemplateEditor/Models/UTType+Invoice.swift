import UniformTypeIdentifiers

extension UTType {
    static let invoiceComponent = UTType(exportedAs: "com.example.invoice-component", conformingTo: .data)
    static let sectionComponent = UTType(exportedAs: "com.example.section-component", conformingTo: .data)
}
