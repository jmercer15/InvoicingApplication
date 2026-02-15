import Foundation

/// Represents a specific row and column in the grid.
public struct GridCoordinate: Hashable, Equatable, Comparable, Sendable {
    public var row: Int
    public var column: Int
    
    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
    
    public static func < (lhs: GridCoordinate, rhs: GridCoordinate) -> Bool {
        if lhs.row != rhs.row { return lhs.row < rhs.row }
        return lhs.column < rhs.column
    }
}
