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
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = Date()
        self.modifiedAt = Date()
        self.version = "1.0"
        self.author = author
        self.tags = tags
        self.thumbnailData = thumbnailData
    }
    
    mutating func updateModifiedDate() {
        // Note: This creates a new instance since structs are immutable
        // In practice, we'll create a new metadata instance when saving
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
        self.components = document.components
        self.margins = DocumentMarginsData(from: document.margins)
        self.zoom = document.zoom
    }
    
    func apply(to document: InvoiceDocument) {
        document.components = components
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
