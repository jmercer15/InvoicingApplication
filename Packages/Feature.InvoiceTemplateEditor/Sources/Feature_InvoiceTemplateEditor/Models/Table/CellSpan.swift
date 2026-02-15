import Foundation

/// Represents the span of a cell in the grid.
public struct CellSpan: Hashable, Equatable, Sendable {
    public var rowSpan: Int
    public var colSpan: Int
    
    public static let standard = CellSpan(rowSpan: 1, colSpan: 1)
    
    public init(rowSpan: Int, colSpan: Int) {
        self.rowSpan = rowSpan
        self.colSpan = colSpan
    }
}
