import SwiftUI

/// Caches the computed dimensions of the table to avoid O(N^2) calculations.
public struct TableLayoutCache {
    public var columnWidths: [CGFloat]
    public var rowHeights: [CGFloat]
    public var totalSize: CGSize
    
    public init(columnWidths: [CGFloat] = [], rowHeights: [CGFloat] = [], totalSize: CGSize = .zero) {
        self.columnWidths = columnWidths
        self.rowHeights = rowHeights
        self.totalSize = totalSize
    }
}
