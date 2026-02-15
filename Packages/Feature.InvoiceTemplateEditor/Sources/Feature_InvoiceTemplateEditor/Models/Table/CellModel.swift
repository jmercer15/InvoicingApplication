import Foundation

/// Represents a single cell in the table.
public struct CellModel: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var content: RichTextContent
    public var coordinate: GridCoordinate
    public var span: CellSpan
    public var isVisible: Bool
    public var style: CellStyle
    
    public init(id: UUID = UUID(), content: RichTextContent = RichTextContent(), coordinate: GridCoordinate, span: CellSpan = .standard, isVisible: Bool = true, style: CellStyle = .standard) {
        self.id = id
        self.content = content
        self.coordinate = coordinate
        self.span = span
        self.isVisible = isVisible
        self.style = style
    }
}
