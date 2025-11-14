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
    
    // Optional fields for backward compatibility (older templates may not have these)
    let sectionSplits: [Int: SectionSplit]? // Split structure with components, labels, and alignments
    let pageSize: CGSize? // Page size (optional for backward compatibility)
    
    init(from document: InvoiceDocument) {
        // Save all components (includes both legacy components and components in splits)
        self.components = document.getAllComponents()
        self.margins = DocumentMarginsData(from: document.margins)
        self.zoom = document.zoom
        // Save the complete split structure including nested splits, components, labels, and alignments
        // Empty dictionary is saved as nil for cleaner JSON (older templates don't have this field)
        self.sectionSplits = document.sectionSplits.isEmpty ? nil : document.sectionSplits
        // Save page size (optional for backward compatibility)
        self.pageSize = document.pageSize
    }
    
    func apply(to document: InvoiceDocument) {
        // Restore document properties
        document.margins = margins.toDocumentMargins()
        document.zoom = zoom
        
        // Restore page size if present (for backward compatibility with older templates)
        if let pageSize = pageSize {
            document.pageSize = pageSize
        }
        
        // Restore split structure (this includes components stored in splits)
        // Use empty dictionary if sectionSplits is nil (for backward compatibility with older templates)
        let splitsToRestore = sectionSplits ?? [:]
        document.sectionSplits = splitsToRestore
        
        // Separate components into legacy components (not in any split) and split components
        // For older templates without splits, all components go to the legacy array
        let allComponentsInSplits = splitsToRestore.values.flatMap { split in
            split.getAllComponents()
        }
        let componentIdsInSplits = Set(allComponentsInSplits.map { $0.id })
        
        // Restore legacy components (components not stored in any split)
        document.components = components.filter { component in
            !componentIdsInSplits.contains(component.id)
        }
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
