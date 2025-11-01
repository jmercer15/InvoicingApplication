import Foundation

struct TemplateMetadata: Codable {
    let id: UUID
    let name: String
    let description: String
    let createdAt: Date
    let modifiedAt: Date
    let version: String
    let author: String
    let tags: [String]
    let thumbnailData: Data?
    
    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        author: String = "",
        tags: [String] = [],
        thumbnailData: Data? = nil,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        version: String = "1.0"
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.version = version
        self.author = author
        self.tags = tags
        self.thumbnailData = thumbnailData
    }
}

struct TemplateData: Codable {
    let metadata: TemplateMetadata
    let document: InvoiceDocumentData
    
    init(metadata: TemplateMetadata, document: InvoiceDocumentData) {
        self.metadata = metadata
        self.document = document
    }
}

// Separate data structure for InvoiceDocument to avoid @Published issues
struct InvoiceDocumentData: Codable {
    let components: [InvoiceComponent]
    let margins: DocumentMarginsData
    let zoom: CGFloat
    
    init(from document: InvoiceDocument) {
        self.components = document.getAllComponents()
        self.margins = DocumentMarginsData(from: document.margins)
        self.zoom = document.zoom
    }
    
    func apply(to document: InvoiceDocument) {
        // For now, only apply legacy components
        // TODO: Add support for split components in template metadata
        document.components = components.filter { component in
            // Only include components that are in the legacy system
            document.components.contains { $0.id == component.id }
        }
        document.margins = margins.toDocumentMargins()
        document.zoom = zoom
    }
}

struct DocumentMarginsData: Codable {
    let left: CGFloat
    let right: CGFloat
    let top: CGFloat
    let bottom: CGFloat
    
    init(from margins: InvoiceDocument.DocumentMargins) {
        self.left = margins.left
        self.right = margins.right
        self.top = margins.top
        self.bottom = margins.bottom
    }
    
    func toDocumentMargins() -> InvoiceDocument.DocumentMargins {
        return InvoiceDocument.DocumentMargins(
            left: left,
            right: right,
            top: top,
            bottom: bottom
        )
    }
}
