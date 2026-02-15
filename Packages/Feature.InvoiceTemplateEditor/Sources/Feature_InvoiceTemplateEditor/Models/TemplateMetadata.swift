import Foundation

public struct TemplateMetadata: Codable, Equatable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String
    public let createdAt: Date
    public let modifiedAt: Date
    public let version: String
    public let author: String
    public let tags: [String]
    public let thumbnailData: Data?
    
    public init(
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

public struct TemplateData: Codable, Sendable {
    public let metadata: TemplateMetadata
    public let document: InvoiceDocumentData
    
    public init(metadata: TemplateMetadata, document: InvoiceDocumentData) {
        self.metadata = metadata
        self.document = document
    }
}

// Separate data structure for InvoiceDocument to avoid @Published issues
public struct InvoiceDocumentData: Codable, Sendable {
    public let components: [InvoiceComponent]
    public let margins: DocumentMarginsData
    public let zoom: CGFloat
    
    // Optional fields for backward compatibility (older templates may not have these)
    public let sectionSplits: [Int: SectionSplit]? // Split structure with components, labels, and alignments
    public let pageSize: CGSize? // Page size (optional for backward compatibility)
    
    public init(from document: InvoiceDocument) {
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
    
    public func apply(to document: InvoiceDocument) {
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

public struct DocumentMarginsData: Codable, Sendable {
    public let left: CGFloat
    public let right: CGFloat
    public let top: CGFloat
    public let bottom: CGFloat
    
    public init(from margins: InvoiceDocument.DocumentMargins) {
        self.left = margins.left
        self.right = margins.right
        self.top = margins.top
        self.bottom = margins.bottom
    }
    
    public func toDocumentMargins() -> InvoiceDocument.DocumentMargins {
        return InvoiceDocument.DocumentMargins(
            left: left,
            right: right,
            top: top,
            bottom: bottom
        )
    }
}
