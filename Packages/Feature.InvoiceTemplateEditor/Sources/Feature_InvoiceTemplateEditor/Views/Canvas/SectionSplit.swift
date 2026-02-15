//
//  SectionSplit.swift
//  Feature.InvoiceTemplateEditor
//
//  Model for representing a split section with nested subsections
//

import Foundation
import Core
import SwiftUI

/// Model representing a split section that can be recursively subdivided
public struct SectionSplit: Codable, Sendable {
    public struct PaddingInsets: Codable, Equatable, Sendable {
        public var top: CGFloat
        public var leading: CGFloat
        public var bottom: CGFloat
        public var trailing: CGFloat
        
        public static let zero = PaddingInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        
        public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) {
            self.top = top
            self.leading = leading
            self.bottom = bottom
            self.trailing = trailing
        }
    }
    
    public enum SizingMode: String, Codable, CaseIterable, Sendable {
        case fixed // Ratio-based (default)
        case expand // Takes remaining space
        case shrink // Shrinks to fit content
        
        public var displayName: String {
            switch self {
            case .fixed: return "Fixed Ratio"
            case .expand: return "Expand"
            case .shrink: return "Shrink to Fit"
            }
        }
        
        public var icon: String {
            switch self {
            case .fixed: return "arrow.left.and.right"
            case .expand: return "arrow.up.left.and.arrow.down.right"
            case .shrink: return "arrow.down.right.and.arrow.up.left"
            }
        }
    }
    
    
    public let direction: SplitDirection
    public var splitRatios: [CGFloat] // For custom sizing - now mutable
    public var children: [SectionSplit?] // Nested subsections
    public var childComponents: [Int: [InvoiceComponent]] = [:] // Components per child index (for leaf children)
    public var childLabels: [Int: String] = [:] // Labels for each child section
    public var childAlignments: [Int: LeafAlignment] = [:] // Alignment for each leaf child section
    public var childWidthSizingModes: [SizingMode] = [] // Width sizing mode for each child
    public var childHeightSizingModes: [SizingMode] = [] // Height sizing mode for each child
    public var childPaddings: [PaddingInsets] = [] // Internal padding per child
    public var childSpacing: CGFloat = 0 // Spacing between children
    public var padding: CGFloat = 0 // Internal padding
    public var margin: CGFloat = 0 // External padding around the split
    public let id: UUID
    
    // Grid-specific properties
    public var gridRows: Int = 2
    public var gridColumns: Int = 2
    public var heightRatios: [CGFloat] = [] // For grid: row height ratios
    public var widthRatios: [CGFloat] = [] // For grid: column width ratios
    public var rowSizingModes: [SizingMode] = [] // Sizing mode for each row
    public var columnSizingModes: [SizingMode] = [] // Sizing mode for each column
    
    /// The number of children in this split (computed from children array or grid dimensions)
    public var splitCount: Int {
        if direction == .grid {
            return gridRows * gridColumns
        } else {
            return children.count
        }
    }
    
    // CodingKeys for custom decoding
    private enum CodingKeys: String, CodingKey {
        case direction, splitCount, splitRatios, children, childComponents, childLabels, childAlignments
        case childWidthSizingModes, childHeightSizingModes, childSizingModes // childSizingModes for migration
        case childPaddings
        case childSpacing, padding, margin
        case id, gridRows, gridColumns, heightRatios, widthRatios, rowSizingModes, columnSizingModes
    }
    
    public init(direction: SplitDirection, splitCount: Int, splitRatios: [CGFloat]? = nil) {
        self.direction = direction
        self.id = UUID()
        
        if let ratios = splitRatios, ratios.count == splitCount {
            self.splitRatios = ratios
        } else {
            // Default equal ratios
            self.splitRatios = Array(repeating: 1.0 / CGFloat(splitCount), count: splitCount)
        }
        
        // Initialize children as nil (unsplit)
        self.children = Array(repeating: nil, count: splitCount)
        
        // Initialize sizing modes
        self.childWidthSizingModes = Array(repeating: .fixed, count: splitCount)
        self.childHeightSizingModes = Array(repeating: .fixed, count: splitCount)
        self.childPaddings = Array(repeating: .zero, count: splitCount)
        self.childSpacing = 0
        self.padding = 0
        self.margin = 0
        
        // Initialize grid-specific properties
        if direction == .grid {
            self.gridRows = 2
            self.gridColumns = 2
            self.heightRatios = Array(repeating: 1.0 / CGFloat(gridRows), count: gridRows)
            self.widthRatios = Array(repeating: 1.0 / CGFloat(gridColumns), count: gridColumns)
            self.rowSizingModes = Array(repeating: .fixed, count: gridRows)
            self.columnSizingModes = Array(repeating: .fixed, count: gridColumns)
        }
    }
    
    // Grid-specific initializer
    public init(gridRows: Int, gridColumns: Int, heightRatios: [CGFloat]? = nil, widthRatios: [CGFloat]? = nil) {
        self.direction = .grid
        self.id = UUID()
        self.gridRows = gridRows
        self.gridColumns = gridColumns
        
        let splitCount = gridRows * gridColumns
        
        // Initialize children as nil (unsplit)
        self.children = Array(repeating: nil, count: splitCount)
        
        // Initialize sizing modes
        self.childWidthSizingModes = Array(repeating: .fixed, count: splitCount)
        self.childHeightSizingModes = Array(repeating: .fixed, count: splitCount)
        self.childPaddings = Array(repeating: .zero, count: splitCount)
        self.childSpacing = 0
        self.padding = 0
        self.margin = 0
        
        // Set height ratios
        if let ratios = heightRatios, ratios.count == gridRows {
            self.heightRatios = ratios
        } else {
            self.heightRatios = Array(repeating: 1.0 / CGFloat(gridRows), count: gridRows)
        }
        self.rowSizingModes = Array(repeating: .fixed, count: gridRows)
        
        // Set width ratios
        if let ratios = widthRatios, ratios.count == gridColumns {
            self.widthRatios = ratios
        } else {
            self.widthRatios = Array(repeating: 1.0 / CGFloat(gridColumns), count: gridColumns)
        }
        self.columnSizingModes = Array(repeating: .fixed, count: gridColumns)
        
        // Legacy splitRatios for compatibility (not used for grid)
        self.splitRatios = Array(repeating: 1.0 / CGFloat(splitCount), count: splitCount)
    }
    
    // Custom decoding to handle migration
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        direction = try container.decode(SplitDirection.self, forKey: .direction)
        // splitCount is now computed, but we read it for validation/backward compatibility
        let decodedSplitCount = try container.decode(Int.self, forKey: .splitCount)
        splitRatios = try container.decode([CGFloat].self, forKey: .splitRatios)
        children = try container.decode([SectionSplit?].self, forKey: .children)
        childComponents = try container.decodeIfPresent([Int: [InvoiceComponent]].self, forKey: .childComponents) ?? [:]
        childLabels = try container.decodeIfPresent([Int: String].self, forKey: .childLabels) ?? [:]
        childAlignments = try container.decodeIfPresent([Int: LeafAlignment].self, forKey: .childAlignments) ?? [:]
        id = try container.decode(UUID.self, forKey: .id)
        
        gridRows = try container.decodeIfPresent(Int.self, forKey: .gridRows) ?? 2
        gridColumns = try container.decodeIfPresent(Int.self, forKey: .gridColumns) ?? 2
        
        // Use the decoded splitCount for array initialization
        let splitCount = decodedSplitCount
        
        // Try decoding new properties, fallback to defaults
        // Handle migration from old childSizingModes to new width/height arrays
        if let widthModes = try? container.decodeIfPresent([SizingMode].self, forKey: .childWidthSizingModes) {
            childWidthSizingModes = widthModes
        } else if let oldModes = try? container.decodeIfPresent([SizingMode].self, forKey: .childSizingModes) {
            // Migrate from old single array
            childWidthSizingModes = oldModes
        } else {
            childWidthSizingModes = Array(repeating: .fixed, count: splitCount)
        }
        
        if let heightModes = try? container.decodeIfPresent([SizingMode].self, forKey: .childHeightSizingModes) {
            childHeightSizingModes = heightModes
        } else if let oldModes = try? container.decodeIfPresent([SizingMode].self, forKey: .childSizingModes) {
            // Migrate from old single array
            childHeightSizingModes = oldModes
        } else {
            childHeightSizingModes = Array(repeating: .fixed, count: splitCount)
        }
        
        if let paddings = try? container.decodeIfPresent([PaddingInsets].self, forKey: .childPaddings) {
            childPaddings = paddings
        } else {
            childPaddings = Array(repeating: .zero, count: splitCount)
        }
        childSpacing = try container.decodeIfPresent(CGFloat.self, forKey: .childSpacing) ?? 0
        padding = try container.decodeIfPresent(CGFloat.self, forKey: .padding) ?? 0
        margin = try container.decodeIfPresent(CGFloat.self, forKey: .margin) ?? 0
        
        heightRatios = try container.decodeIfPresent([CGFloat].self, forKey: .heightRatios) ?? []
        widthRatios = try container.decodeIfPresent([CGFloat].self, forKey: .widthRatios) ?? []
        
        rowSizingModes = try container.decodeIfPresent([SizingMode].self, forKey: .rowSizingModes) ?? Array(repeating: .fixed, count: gridRows)
        columnSizingModes = try container.decodeIfPresent([SizingMode].self, forKey: .columnSizingModes) ?? Array(repeating: .fixed, count: gridColumns)
        
        // Ensure arrays are correct size if defaults were used but dimensions differ
        if rowSizingModes.count != gridRows {
            rowSizingModes = Array(repeating: .fixed, count: gridRows)
        }
        if columnSizingModes.count != gridColumns {
            columnSizingModes = Array(repeating: .fixed, count: gridColumns)
        }
        if childPaddings.count != self.splitCount {
            childPaddings = Array(repeating: .zero, count: self.splitCount)
        }
    }
    
    // Custom encoding
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(direction, forKey: .direction)
        try container.encode(splitCount, forKey: .splitCount)
        try container.encode(splitRatios, forKey: .splitRatios)
        try container.encode(children, forKey: .children)
        try container.encode(childComponents, forKey: .childComponents)
        try container.encode(childLabels, forKey: .childLabels)
        try container.encode(childAlignments, forKey: .childAlignments)
        try container.encode(childWidthSizingModes, forKey: .childWidthSizingModes)
        try container.encode(childHeightSizingModes, forKey: .childHeightSizingModes)
        try container.encode(childPaddings, forKey: .childPaddings)
        try container.encode(childSpacing, forKey: .childSpacing)
        try container.encode(padding, forKey: .padding)
        try container.encode(margin, forKey: .margin)
        try container.encode(id, forKey: .id)
        try container.encode(gridRows, forKey: .gridRows)
        try container.encode(gridColumns, forKey: .gridColumns)
        try container.encode(heightRatios, forKey: .heightRatios)
        try container.encode(widthRatios, forKey: .widthRatios)
        try container.encode(rowSizingModes, forKey: .rowSizingModes)
        try container.encode(columnSizingModes, forKey: .columnSizingModes)
    }
    
    mutating func updateRatio(at index: Int, newRatio: CGFloat) {
        guard index < splitRatios.count else { return }
        
        // Constrain the new ratio
        let constrainedRatio = max(0.05, min(0.95, newRatio))
        
        // Calculate how much the ratio changed
        let ratioChange = constrainedRatio - splitRatios[index]
        
        // Update the target ratio
        splitRatios[index] = constrainedRatio
        
        // Distribute the change proportionally among other ratios
        let otherIndices = (0..<splitRatios.count).filter { $0 != index }
        let totalOtherRatio = otherIndices.reduce(0) { $0 + splitRatios[$1] }
        
        if totalOtherRatio > 0 && otherIndices.count > 0 {
            // Distribute the change proportionally
            for otherIndex in otherIndices {
                let proportion = splitRatios[otherIndex] / totalOtherRatio
                let adjustment = -ratioChange * proportion
                splitRatios[otherIndex] = max(0.05, splitRatios[otherIndex] + adjustment)
            }
        }
        
        // Final normalization to ensure sum is 1.0
        let total = splitRatios.reduce(0, +)
        if total > 0 {
            splitRatios = splitRatios.map { $0 / total }
        }
    }

    mutating func resetRatiosToEvenDistribution() {
        guard splitCount > 0 else { return }
        let evenValue = 1.0 / CGFloat(splitCount)
        splitRatios = Array(repeating: evenValue, count: splitCount)
    }
    
    mutating func splitChild(at index: Int, direction: SplitDirection, splitCount: Int) {
        guard index < children.count else { return }
        
        // Get existing components from this leaf node before splitting
        let existingComponents = childComponents[index] ?? []
        childComponents.removeValue(forKey: index) // Remove from this level since it's no longer a leaf
        
        if direction == .grid {
            // For grid, we need to determine rows and columns from splitCount
            // Default to 2x2 for now, but this could be enhanced to accept custom dimensions
            let rows = Int(sqrt(Double(splitCount)))
            let columns = splitCount / rows
            var newSplit = SectionSplit(gridRows: rows, gridColumns: columns)
            
            // Distribute existing components to the new children
            Self.distributeComponents(existingComponents, to: &newSplit, childCount: splitCount)
            
            children[index] = newSplit
        } else {
            var newSplit = SectionSplit(direction: direction, splitCount: splitCount)
            
            // Distribute existing components to the new children
            Self.distributeComponents(existingComponents, to: &newSplit, childCount: splitCount)
            
            children[index] = newSplit
        }
    }
    
    mutating func splitChild(at index: Int, direction: SplitDirection, splitCount: Int, gridRows: Int, gridColumns: Int) {
        guard index < children.count else { return }
        
        // Get existing components from this leaf node before splitting
        let existingComponents = childComponents[index] ?? []
        childComponents.removeValue(forKey: index) // Remove from this level since it's no longer a leaf
        
        if direction == .grid {
            var newSplit = SectionSplit(gridRows: gridRows, gridColumns: gridColumns)
            
            // Distribute existing components to the new children
            Self.distributeComponents(existingComponents, to: &newSplit, childCount: splitCount)
            
            children[index] = newSplit
        } else {
            var newSplit = SectionSplit(direction: direction, splitCount: splitCount)
            
            // Distribute existing components to the new children
            Self.distributeComponents(existingComponents, to: &newSplit, childCount: splitCount)
            
            children[index] = newSplit
        }
    }
    
    // Helper method to distribute components evenly across children
    private static func distributeComponents(_ components: [InvoiceComponent], to split: inout SectionSplit, childCount: Int) {
        guard !components.isEmpty && childCount > 0 else { return }
        
        // Distribute components evenly across children
        // If there are more components than children, they'll be distributed round-robin style
        for (index, component) in components.enumerated() {
            let targetChildIndex = index % childCount
            split.addComponent(component, toChild: targetChildIndex)
        }
    }
    
    mutating func unsplitChild(at index: Int) {
        guard index < children.count else { return }
        children[index] = nil
    }
    
    /// Insert a new child at the specified index, shifting existing children
    mutating func insertChild(at index: Int) {
        guard index >= 0 && index <= splitCount else { return }
        
        let newCount = splitCount + 1
        
        if direction == .grid {
            // For grid, we need to recalculate dimensions
            let newRows = Int(sqrt(Double(newCount)))
            let newColumns = (newCount + newRows - 1) / newRows
            
            // Collect existing content
            var existingChildren: [SectionSplit?] = children
            var existingComponents: [Int: [InvoiceComponent]] = childComponents
            var existingLabels: [Int: String] = childLabels
            var existingAlignments: [Int: LeafAlignment] = childAlignments
            var existingWidthModes: [SizingMode] = childWidthSizingModes
            var existingHeightModes: [SizingMode] = childHeightSizingModes
            var existingPaddings: [PaddingInsets] = childPaddings
            
            // Update grid dimensions
            gridRows = newRows
            gridColumns = newColumns
            
            // Create new arrays with inserted nil child
            children = Array(repeating: nil, count: newCount)
            childComponents = [:]
            childLabels = [:]
            childAlignments = [:]
            childWidthSizingModes = Array(repeating: .fixed, count: newCount)
            childHeightSizingModes = Array(repeating: .fixed, count: newCount)
            childPaddings = Array(repeating: .zero, count: newCount)
            
            // Redistribute content, shifting indices after insertion point
            for i in 0..<newCount {
                if i < index {
                    children[i] = existingChildren[i]
                    if let components = existingComponents[i] {
                        childComponents[i] = components
                    }
                    if let label = existingLabels[i] {
                        childLabels[i] = label
                    }
                    if let alignment = existingAlignments[i] {
                        childAlignments[i] = alignment
                    }
                    if i < existingWidthModes.count {
                        childWidthSizingModes[i] = existingWidthModes[i]
                    }
                    if i < existingHeightModes.count {
                        childHeightSizingModes[i] = existingHeightModes[i]
                    }
                    if i < existingPaddings.count {
                        childPaddings[i] = existingPaddings[i]
                    }
                } else if i == index {
                    // New child stays nil
                } else {
                    let oldIndex = i - 1
                    children[i] = existingChildren[oldIndex]
                    if let components = existingComponents[oldIndex] {
                        childComponents[i] = components
                    }
                    if let label = existingLabels[oldIndex] {
                        childLabels[i] = label
                    }
                    if let alignment = existingAlignments[oldIndex] {
                        childAlignments[i] = alignment
                    }
                    if oldIndex < existingWidthModes.count {
                        childWidthSizingModes[i] = existingWidthModes[oldIndex]
                    }
                    if oldIndex < existingHeightModes.count {
                        childHeightSizingModes[i] = existingHeightModes[oldIndex]
                    }
                    if oldIndex < existingPaddings.count {
                        childPaddings[i] = existingPaddings[oldIndex]
                    }
                }
            }
            
            // Update ratios
            splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
            heightRatios = Array(repeating: 1.0 / CGFloat(newRows), count: newRows)
            widthRatios = Array(repeating: 1.0 / CGFloat(newColumns), count: newColumns)
            rowSizingModes = Array(repeating: .fixed, count: newRows)
            columnSizingModes = Array(repeating: .fixed, count: newColumns)
            
        } else {
            // For linear splits
            var newChildren: [SectionSplit?] = []
            var newComponents: [Int: [InvoiceComponent]] = [:]
            var newLabels: [Int: String] = [:]
            var newAlignments: [Int: LeafAlignment] = [:]
            var newWidthModes: [SizingMode] = []
            var newHeightModes: [SizingMode] = []
            var newPaddings: [PaddingInsets] = []
            
            for i in 0..<newCount {
                if i < index {
                    // Before insertion point - keep as is
                    newChildren.append(children[i])
                    if let components = childComponents[i] {
                        newComponents[i] = components
                    }
                    if let label = childLabels[i] {
                        newLabels[i] = label
                    }
                    if let alignment = childAlignments[i] {
                        newAlignments[i] = alignment
                    }
                    if i < childWidthSizingModes.count {
                        newWidthModes.append(childWidthSizingModes[i])
                    } else {
                        newWidthModes.append(.fixed)
                    }
                    if i < childHeightSizingModes.count {
                        newHeightModes.append(childHeightSizingModes[i])
                    } else {
                        newHeightModes.append(.fixed)
                    }
                    if i < childPaddings.count {
                        newPaddings.append(childPaddings[i])
                    } else {
                        newPaddings.append(.zero)
                    }
                } else if i == index {
                    // Insertion point - add new nil child
                    newChildren.append(nil)
                    newWidthModes.append(.fixed)
                    newHeightModes.append(.fixed)
                    newPaddings.append(.zero)
                } else {
                    // After insertion point - shift from old index
                    let oldIndex = i - 1
                    newChildren.append(children[oldIndex])
                    if let components = childComponents[oldIndex] {
                        newComponents[i] = components
                    }
                    if let label = childLabels[oldIndex] {
                        newLabels[i] = label
                    }
                    if let alignment = childAlignments[oldIndex] {
                        newAlignments[i] = alignment
                    }
                    if oldIndex < childWidthSizingModes.count {
                        newWidthModes.append(childWidthSizingModes[oldIndex])
                    } else {
                        newWidthModes.append(.fixed)
                    }
                    if oldIndex < childHeightSizingModes.count {
                        newHeightModes.append(childHeightSizingModes[oldIndex])
                    } else {
                        newHeightModes.append(.fixed)
                    }
                    if oldIndex < childPaddings.count {
                        newPaddings.append(childPaddings[oldIndex])
                    } else {
                        newPaddings.append(.zero)
                    }
                }
            }
            
            children = newChildren
            childComponents = newComponents
            childLabels = newLabels
            childAlignments = newAlignments
            childWidthSizingModes = newWidthModes
            childHeightSizingModes = newHeightModes
            childPaddings = newPaddings
            splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
        }
    }
    
    /// Delete a child at the specified index, shifting remaining children
    mutating func deleteChild(at index: Int) -> [InvoiceComponent] {
        guard index >= 0 && index < splitCount && splitCount > 1 else { return [] }
        
        let newCount = splitCount - 1
        var orphanedComponents: [InvoiceComponent] = []
        
        // Collect components from the deleted child
        if let childSplit = children[index] {
            orphanedComponents = childSplit.getAllComponents()
        } else if let components = childComponents[index] {
            orphanedComponents = components
        }
        
        if direction == .grid {
            // For grid, recalculate dimensions
            let newRows = Int(sqrt(Double(newCount)))
            let newColumns = (newCount + newRows - 1) / newRows
            
            var newChildren: [SectionSplit?] = []
            var newComponents: [Int: [InvoiceComponent]] = [:]
            var newLabels: [Int: String] = [:]
            var newAlignments: [Int: LeafAlignment] = [:]
            var newWidthModes: [SizingMode] = []
            var newHeightModes: [SizingMode] = []
            var newPaddings: [PaddingInsets] = []
            
            var newIndex = 0
            for i in 0..<splitCount {
                if i == index {
                    continue // Skip deleted child
                }
                
                newChildren.append(children[i])
                if let components = childComponents[i] {
                    newComponents[newIndex] = components
                }
                if let label = childLabels[i] {
                    newLabels[newIndex] = label
                }
                if let alignment = childAlignments[i] {
                    newAlignments[newIndex] = alignment
                }
                if i < childWidthSizingModes.count {
                    newWidthModes.append(childWidthSizingModes[i])
                }
                if i < childHeightSizingModes.count {
                    newHeightModes.append(childHeightSizingModes[i])
                }
                if i < childPaddings.count {
                    newPaddings.append(childPaddings[i])
                }
                newIndex += 1
            }
            
            gridRows = newRows
            gridColumns = newColumns
            children = newChildren
            childComponents = newComponents
            childLabels = newLabels
            childAlignments = newAlignments
            childWidthSizingModes = newWidthModes
            childHeightSizingModes = newHeightModes
            childPaddings = newPaddings
            splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
            heightRatios = Array(repeating: 1.0 / CGFloat(newRows), count: newRows)
            widthRatios = Array(repeating: 1.0 / CGFloat(newColumns), count: newColumns)
            rowSizingModes = Array(repeating: .fixed, count: newRows)
            columnSizingModes = Array(repeating: .fixed, count: newColumns)
            
        } else {
            // For linear splits
            var newChildren: [SectionSplit?] = []
            var newComponents: [Int: [InvoiceComponent]] = [:]
            var newLabels: [Int: String] = [:]
            var newAlignments: [Int: LeafAlignment] = [:]
            var newWidthModes: [SizingMode] = []
            var newHeightModes: [SizingMode] = []
            var newPaddings: [PaddingInsets] = []
            
            var newIndex = 0
            for i in 0..<splitCount {
                if i == index {
                    continue // Skip deleted child
                }
                
                newChildren.append(children[i])
                if let components = childComponents[i] {
                    newComponents[newIndex] = components
                }
                if let label = childLabels[i] {
                    newLabels[newIndex] = label
                }
                if let alignment = childAlignments[i] {
                    newAlignments[newIndex] = alignment
                }
                if i < childWidthSizingModes.count {
                    newWidthModes.append(childWidthSizingModes[i])
                }
                if i < childHeightSizingModes.count {
                    newHeightModes.append(childHeightSizingModes[i])
                }
                if i < childPaddings.count {
                    newPaddings.append(childPaddings[i])
                }
                newIndex += 1
            }
            
            children = newChildren
            childComponents = newComponents
            childLabels = newLabels
            childAlignments = newAlignments
            childWidthSizingModes = newWidthModes
            childHeightSizingModes = newHeightModes
            childPaddings = newPaddings
            splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
        }
        
        return orphanedComponents
    }
    
    // MARK: - Grid-specific insert/delete operations
    
    /// Insert a new row in a grid split at the specified row index
    mutating func insertGridRow(at rowIndex: Int) {
        guard direction == .grid, rowIndex >= 0, rowIndex <= gridRows else { return }
        
        let newRows = gridRows + 1
        let newCount = newRows * gridColumns
        
        // Collect existing content
        var newChildren: [SectionSplit?] = []
        var newComponents: [Int: [InvoiceComponent]] = [:]
        var newLabels: [Int: String] = [:]
        var newAlignments: [Int: LeafAlignment] = [:]
        var newWidthModes: [SizingMode] = []
        var newHeightModes: [SizingMode] = []
        var newPaddings: [PaddingInsets] = []
        
        // Rebuild grid with new row inserted
        for row in 0..<newRows {
            for col in 0..<gridColumns {
                if row < rowIndex {
                    // Before insertion - copy from old grid
                    let oldIndex = cellIndex(row: row, column: col)
                    newChildren.append(children[oldIndex])
                    if let components = childComponents[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newComponents[newIndex] = components
                    }
                    if let label = childLabels[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newLabels[newIndex] = label
                    }
                    if let alignment = childAlignments[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newAlignments[newIndex] = alignment
                    }
                    if oldIndex < childWidthSizingModes.count {
                        newWidthModes.append(childWidthSizingModes[oldIndex])
                    } else {
                        newWidthModes.append(.fixed)
                    }
                    if oldIndex < childHeightSizingModes.count {
                        newHeightModes.append(childHeightSizingModes[oldIndex])
                    } else {
                        newHeightModes.append(.fixed)
                    }
                    if oldIndex < childPaddings.count {
                        newPaddings.append(childPaddings[oldIndex])
                    } else {
                        newPaddings.append(.zero)
                    }
                } else if row == rowIndex {
                    // New row - add empty cells
                    newChildren.append(nil)
                    newWidthModes.append(.fixed)
                    newHeightModes.append(.fixed)
                    newPaddings.append(.zero)
                } else {
                    // After insertion - copy from old grid (shifted by one row)
                    let oldIndex = cellIndex(row: row - 1, column: col)
                    newChildren.append(children[oldIndex])
                    if let components = childComponents[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newComponents[newIndex] = components
                    }
                    if let label = childLabels[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newLabels[newIndex] = label
                    }
                    if let alignment = childAlignments[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newAlignments[newIndex] = alignment
                    }
                    if oldIndex < childWidthSizingModes.count {
                        newWidthModes.append(childWidthSizingModes[oldIndex])
                    } else {
                        newWidthModes.append(.fixed)
                    }
                    if oldIndex < childHeightSizingModes.count {
                        newHeightModes.append(childHeightSizingModes[oldIndex])
                    } else {
                        newHeightModes.append(.fixed)
                    }
                    if oldIndex < childPaddings.count {
                        newPaddings.append(childPaddings[oldIndex])
                    } else {
                        newPaddings.append(.zero)
                    }
                }
            }
        }
        
        gridRows = newRows
        children = newChildren
        childComponents = newComponents
        childLabels = newLabels
        childAlignments = newAlignments
        childWidthSizingModes = newWidthModes
        childHeightSizingModes = newHeightModes
        childPaddings = newPaddings
        splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
        heightRatios = Array(repeating: 1.0 / CGFloat(newRows), count: newRows)
        rowSizingModes = Array(repeating: .fixed, count: newRows)
    }
    
    /// Insert a new column in a grid split at the specified column index
    mutating func insertGridColumn(at columnIndex: Int) {
        guard direction == .grid, columnIndex >= 0, columnIndex <= gridColumns else { return }
        
        let newColumns = gridColumns + 1
        let newCount = gridRows * newColumns
        
        // Collect existing content
        var newChildren: [SectionSplit?] = []
        var newComponents: [Int: [InvoiceComponent]] = [:]
        var newLabels: [Int: String] = [:]
        var newAlignments: [Int: LeafAlignment] = [:]
        var newWidthModes: [SizingMode] = []
        var newHeightModes: [SizingMode] = []
        var newPaddings: [PaddingInsets] = []
        
        // Rebuild grid with new column inserted
        for row in 0..<gridRows {
            for col in 0..<newColumns {
                if col < columnIndex {
                    // Before insertion - copy from old grid
                    let oldIndex = cellIndex(row: row, column: col)
                    newChildren.append(children[oldIndex])
                    if let components = childComponents[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newComponents[newIndex] = components
                    }
                    if let label = childLabels[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newLabels[newIndex] = label
                    }
                    if let alignment = childAlignments[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newAlignments[newIndex] = alignment
                    }
                    if oldIndex < childWidthSizingModes.count {
                        newWidthModes.append(childWidthSizingModes[oldIndex])
                    } else {
                        newWidthModes.append(.fixed)
                    }
                    if oldIndex < childHeightSizingModes.count {
                        newHeightModes.append(childHeightSizingModes[oldIndex])
                    } else {
                        newHeightModes.append(.fixed)
                    }
                    if oldIndex < childPaddings.count {
                        newPaddings.append(childPaddings[oldIndex])
                    } else {
                        newPaddings.append(.zero)
                    }
                } else if col == columnIndex {
                    // New column - add empty cell
                    newChildren.append(nil)
                    newWidthModes.append(.fixed)
                    newHeightModes.append(.fixed)
                    newPaddings.append(.zero)
                } else {
                    // After insertion - copy from old grid (shifted by one column)
                    let oldIndex = cellIndex(row: row, column: col - 1)
                    newChildren.append(children[oldIndex])
                    if let components = childComponents[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newComponents[newIndex] = components
                    }
                    if let label = childLabels[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newLabels[newIndex] = label
                    }
                    if let alignment = childAlignments[oldIndex] {
                        let newIndex = newChildren.count - 1
                        newAlignments[newIndex] = alignment
                    }
                    if oldIndex < childWidthSizingModes.count {
                        newWidthModes.append(childWidthSizingModes[oldIndex])
                    } else {
                        newWidthModes.append(.fixed)
                    }
                    if oldIndex < childHeightSizingModes.count {
                        newHeightModes.append(childHeightSizingModes[oldIndex])
                    } else {
                        newHeightModes.append(.fixed)
                    }
                    if oldIndex < childPaddings.count {
                        newPaddings.append(childPaddings[oldIndex])
                    } else {
                        newPaddings.append(.zero)
                    }
                }
            }
        }
        
        gridColumns = newColumns
        children = newChildren
        childComponents = newComponents
        childLabels = newLabels
        childAlignments = newAlignments
        childWidthSizingModes = newWidthModes
        childHeightSizingModes = newHeightModes
        childPaddings = newPaddings
        splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
        widthRatios = Array(repeating: 1.0 / CGFloat(newColumns), count: newColumns)
        columnSizingModes = Array(repeating: .fixed, count: newColumns)
    }
    
    /// Delete a row from a grid split
    mutating func deleteGridRow(at rowIndex: Int) -> [InvoiceComponent] {
        guard direction == .grid, rowIndex >= 0, rowIndex < gridRows, gridRows > 1 else { return [] }
        
        var orphanedComponents: [InvoiceComponent] = []
        let newRows = gridRows - 1
        let newCount = newRows * gridColumns
        
        // Collect orphaned components from deleted row
        for col in 0..<gridColumns {
            let deletedIndex = cellIndex(row: rowIndex, column: col)
            if let childSplit = children[deletedIndex] {
                orphanedComponents.append(contentsOf: childSplit.getAllComponents())
            } else if let components = childComponents[deletedIndex] {
                orphanedComponents.append(contentsOf: components)
            }
        }
        
        // Rebuild grid without deleted row
        var newChildren: [SectionSplit?] = []
        var newComponents: [Int: [InvoiceComponent]] = [:]
        var newLabels: [Int: String] = [:]
        var newAlignments: [Int: LeafAlignment] = [:]
        var newWidthModes: [SizingMode] = []
        var newHeightModes: [SizingMode] = []
        var newPaddings: [PaddingInsets] = []
        
        for row in 0..<gridRows {
            if row == rowIndex {
                continue // Skip deleted row
            }
            
            for col in 0..<gridColumns {
                let oldIndex = cellIndex(row: row, column: col)
                newChildren.append(children[oldIndex])
                
                let newIndex = newChildren.count - 1
                if let components = childComponents[oldIndex] {
                    newComponents[newIndex] = components
                }
                if let label = childLabels[oldIndex] {
                    newLabels[newIndex] = label
                }
                if let alignment = childAlignments[oldIndex] {
                    newAlignments[newIndex] = alignment
                }
                if oldIndex < childWidthSizingModes.count {
                    newWidthModes.append(childWidthSizingModes[oldIndex])
                }
                if oldIndex < childHeightSizingModes.count {
                    newHeightModes.append(childHeightSizingModes[oldIndex])
                }
                if oldIndex < childPaddings.count {
                    newPaddings.append(childPaddings[oldIndex])
                }
            }
        }
        
        gridRows = newRows
        children = newChildren
        childComponents = newComponents
        childLabels = newLabels
        childAlignments = newAlignments
        childWidthSizingModes = newWidthModes
        childHeightSizingModes = newHeightModes
        childPaddings = newPaddings
        splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
        heightRatios = Array(repeating: 1.0 / CGFloat(newRows), count: newRows)
        rowSizingModes = Array(repeating: .fixed, count: newRows)
        
        return orphanedComponents
    }
    
    /// Delete a column from a grid split
    mutating func deleteGridColumn(at columnIndex: Int) -> [InvoiceComponent] {
        guard direction == .grid, columnIndex >= 0, columnIndex < gridColumns, gridColumns > 1 else { return [] }
        
        var orphanedComponents: [InvoiceComponent] = []
        let newColumns = gridColumns - 1
        let newCount = gridRows * newColumns
        
        // Collect orphaned components from deleted column
        for row in 0..<gridRows {
            let deletedIndex = cellIndex(row: row, column: columnIndex)
            if let childSplit = children[deletedIndex] {
                orphanedComponents.append(contentsOf: childSplit.getAllComponents())
            } else if let components = childComponents[deletedIndex] {
                orphanedComponents.append(contentsOf: components)
            }
        }
        
        // Rebuild grid without deleted column
        var newChildren: [SectionSplit?] = []
        var newComponents: [Int: [InvoiceComponent]] = [:]
        var newLabels: [Int: String] = [:]
        var newAlignments: [Int: LeafAlignment] = [:]
        var newWidthModes: [SizingMode] = []
        var newHeightModes: [SizingMode] = []
        var newPaddings: [PaddingInsets] = []
        
        for row in 0..<gridRows {
            for col in 0..<gridColumns {
                if col == columnIndex {
                    continue // Skip deleted column
                }
                
                let oldIndex = cellIndex(row: row, column: col)
                newChildren.append(children[oldIndex])
                
                let newIndex = newChildren.count - 1
                if let components = childComponents[oldIndex] {
                    newComponents[newIndex] = components
                }
                if let label = childLabels[oldIndex] {
                    newLabels[newIndex] = label
                }
                if let alignment = childAlignments[oldIndex] {
                    newAlignments[newIndex] = alignment
                }
                if oldIndex < childWidthSizingModes.count {
                    newWidthModes.append(childWidthSizingModes[oldIndex])
                }
                if oldIndex < childHeightSizingModes.count {
                    newHeightModes.append(childHeightSizingModes[oldIndex])
                }
                if oldIndex < childPaddings.count {
                    newPaddings.append(childPaddings[oldIndex])
                }
            }
        }
        
        gridColumns = newColumns
        children = newChildren
        childComponents = newComponents
        childLabels = newLabels
        childAlignments = newAlignments
        childWidthSizingModes = newWidthModes
        childHeightSizingModes = newHeightModes
        childPaddings = newPaddings
        splitRatios = Array(repeating: 1.0 / CGFloat(newCount), count: newCount)
        widthRatios = Array(repeating: 1.0 / CGFloat(newColumns), count: newColumns)
        columnSizingModes = Array(repeating: .fixed, count: newColumns)
        
        return orphanedComponents
    }
    
    // Component management methods
    mutating func addComponent(_ component: InvoiceComponent, toChild childIndex: Int) {
        var components = childComponents[childIndex] ?? []
        
        // Check if component already exists to prevent duplicates
        if components.contains(where: { $0.id == component.id }) {
            return
        }
        
        components.append(component)
        childComponents[childIndex] = components
    }
    
    mutating func removeComponent(id: UUID) -> Bool {
        // Check if component is in this split's childComponents
        for (childIndex, var components) in childComponents {
            if components.contains(where: { $0.id == id }) {
                components.removeAll { $0.id == id }
                childComponents[childIndex] = components
                return true
            }
        }
        
        // Recursively check nested children
        for index in 0..<children.count {
            if var child = children[index] {
                if child.removeComponent(id: id) {
                    children[index] = child
                    return true
                }
            }
        }
        
        return false
    }
    
    func findComponentLocation(id: UUID) -> (sectionIndex: Int?, childIndex: Int?)? {
        // Check if component is in this split's childComponents
        for (childIndex, components) in childComponents {
            if components.contains(where: { $0.id == id }) {
                return (nil, childIndex)
            }
        }
        
        // Recursively check nested children
        for index in 0..<children.count {
            if let child = children[index] {
                if let location = child.findComponentLocation(id: id) {
                    return location
                }
            }
        }
        
        return nil
    }
    
    // Get all components from this split and its children
    func getAllComponents() -> [InvoiceComponent] {
        var allComponents: [InvoiceComponent] = []
        
        // Add components from all children
        for (_, components) in childComponents {
            allComponents.append(contentsOf: components)
        }
        
        // Recursively add components from nested splits
        for child in children {
            if let child = child {
                allComponents.append(contentsOf: child.getAllComponents())
            }
        }
        
        return allComponents
    }
    
    // Update a component in this split or its children
    mutating func updateComponent(id: UUID, update: (inout InvoiceComponent) -> Void) -> Bool {
        // Check if component is in this split's childComponents
        for (childIndex, var components) in childComponents {
            if let componentIndex = components.firstIndex(where: { $0.id == id }) {
                update(&components[componentIndex])
                childComponents[childIndex] = components
                return true
            }
        }
        
        // Recursively check nested children
        for index in 0..<children.count {
            if var child = children[index] {
                if child.updateComponent(id: id, update: update) {
                    children[index] = child
                    return true
                }
            }
        }
        
        return false
    }
    
    // Grid-specific ratio update methods
    mutating func updateHeightRatio(at rowIndex: Int, newRatio: CGFloat) {
        guard rowIndex < heightRatios.count else { return }
        
        let constrainedRatio = max(0.05, min(0.95, newRatio))
        let ratioChange = constrainedRatio - heightRatios[rowIndex]
        
        heightRatios[rowIndex] = constrainedRatio
        
        // Distribute the change proportionally among other rows
        let otherIndices = (0..<heightRatios.count).filter { $0 != rowIndex }
        let totalOtherRatio = otherIndices.reduce(0) { $0 + heightRatios[$1] }
        
        if totalOtherRatio > 0 && otherIndices.count > 0 {
            for otherIndex in otherIndices {
                let proportion = heightRatios[otherIndex] / totalOtherRatio
                let adjustment = -ratioChange * proportion
                heightRatios[otherIndex] = max(0.05, heightRatios[otherIndex] + adjustment)
            }
        }
        
        // Final normalization
        let total = heightRatios.reduce(0, +)
        if total > 0 {
            heightRatios = heightRatios.map { $0 / total }
        }
    }
    
    mutating func updateWidthRatio(at columnIndex: Int, newRatio: CGFloat) {
        guard columnIndex < widthRatios.count else { return }
        
        let constrainedRatio = max(0.05, min(0.95, newRatio))
        let ratioChange = constrainedRatio - widthRatios[columnIndex]
        
        widthRatios[columnIndex] = constrainedRatio
        
        // Distribute the change proportionally among other columns
        let otherIndices = (0..<widthRatios.count).filter { $0 != columnIndex }
        let totalOtherRatio = otherIndices.reduce(0) { $0 + widthRatios[$1] }
        
        if totalOtherRatio > 0 && otherIndices.count > 0 {
            for otherIndex in otherIndices {
                let proportion = widthRatios[otherIndex] / totalOtherRatio
                let adjustment = -ratioChange * proportion
                widthRatios[otherIndex] = max(0.05, widthRatios[otherIndex] + adjustment)
            }
        }
        
        // Final normalization
        let total = widthRatios.reduce(0, +)
        if total > 0 {
            widthRatios = widthRatios.map { $0 / total }
        }
    }
    
    // Helper method to get cell index from row/column
    func cellIndex(row: Int, column: Int) -> Int {
        return row * gridColumns + column
    }
    
    // Helper method to get row/column from cell index
    func rowColumn(for cellIndex: Int) -> (row: Int, column: Int) {
        let row = cellIndex / gridColumns
        let column = cellIndex % gridColumns
        return (row: row, column: column)
    }
    
    // MARK: - Label Management
    
    /// Set a label for a specific child section
    mutating func setLabel(_ label: String, forChild childIndex: Int) {
        childLabels[childIndex] = label
    }
    
    /// Get the label for a specific child section
    func getLabel(forChild childIndex: Int) -> String? {
        return childLabels[childIndex]
    }
    
    /// Get a default label for a child section based on its index and direction
    func getDefaultLabel(forChild childIndex: Int) -> String {
        if let existingLabel = childLabels[childIndex], !existingLabel.isEmpty {
            return existingLabel
        }
        
        switch direction {
        case .horizontal:
            return "Column \(childIndex + 1)"
        case .vertical:
            return "Row \(childIndex + 1)"
        case .grid:
            let (row, column) = rowColumn(for: childIndex)
            return "Cell R\(row + 1)C\(column + 1)"
        }
    }
    
    /// Remove a label for a specific child section
    mutating func removeLabel(forChild childIndex: Int) {
        childLabels.removeValue(forKey: childIndex)
    }
    
    // MARK: - Alignment Management
    
    /// Alignment configuration for leaf node content
    public struct LeafAlignment: Codable, Equatable, Sendable {
        public var horizontal: HorizontalAlignment
        public var vertical: VerticalAlignment
        
        public static let `default` = LeafAlignment(horizontal: .leading, vertical: .top)
        
        public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
            self.horizontal = horizontal
            self.vertical = vertical
        }
        
        public enum HorizontalAlignment: String, Codable, CaseIterable, Sendable {
            case leading
            case center
            case trailing
            
            public var swiftUIAlignment: SwiftUI.HorizontalAlignment {
                switch self {
                case .leading: return .leading
                case .center: return .center
                case .trailing: return .trailing
                }
            }
        }
        
        public enum VerticalAlignment: String, Codable, CaseIterable, Sendable {
            case top
            case center
            case bottom
            
            public var swiftUIAlignment: SwiftUI.VerticalAlignment {
                switch self {
                case .top: return .top
                case .center: return .center
                case .bottom: return .bottom
                }
            }
        }
    }
    
    /// Set alignment for a specific leaf child section
    public mutating func setAlignment(_ alignment: LeafAlignment, forChild childIndex: Int) {
        childAlignments[childIndex] = alignment
    }
    
    /// Get the alignment for a specific leaf child section
    public func getAlignment(forChild childIndex: Int) -> LeafAlignment {
        return childAlignments[childIndex] ?? .default
    }
    
    /// Remove alignment for a specific child section (reset to default)
    mutating func removeAlignment(forChild childIndex: Int) {
        childAlignments.removeValue(forKey: childIndex)
    }
    
    // MARK: - Validation
    
    /// Validate the split configuration
    func validate() -> SplitValidationResult {
        var errors: [String] = []
        var warnings: [String] = []
        
        // Check split ratios
        if splitRatios.isEmpty {
            errors.append("Split ratios cannot be empty")
        } else {
            let totalRatio = splitRatios.reduce(0, +)
            if abs(totalRatio - 1.0) > 0.01 {
                errors.append("Split ratios must sum to 1.0 (currently \(String(format: "%.2f", totalRatio)))")
            }
            
            for (index, ratio) in splitRatios.enumerated() {
                if ratio <= 0 {
                    errors.append("Split ratio at index \(index) must be positive (currently \(ratio))")
                }
                if ratio > 1.0 {
                    warnings.append("Split ratio at index \(index) is very large (\(String(format: "%.2f", ratio)))")
                }
            }
        }
        
        // Check children count matches split count
        if children.count != splitCount {
            errors.append("Children count (\(children.count)) does not match split count (\(splitCount))")
        }
        
        // Check grid-specific validation
        if direction == .grid {
            if gridRows <= 0 || gridColumns <= 0 {
                errors.append("Grid dimensions must be positive (rows: \(gridRows), columns: \(gridColumns))")
            }
            
            if gridRows * gridColumns != splitCount {
                errors.append("Grid dimensions (\(gridRows)x\(gridColumns)) do not match split count (\(splitCount))")
            }
            
            if heightRatios.count != gridRows {
                errors.append("Height ratios count (\(heightRatios.count)) does not match grid rows (\(gridRows))")
            }
            
            if widthRatios.count != gridColumns {
                errors.append("Width ratios count (\(widthRatios.count)) does not match grid columns (\(gridColumns))")
            }
        }
        
        // Validate nested splits recursively
        for (index, child) in children.enumerated() {
            if let child = child {
                let childValidation = child.validate()
                for error in childValidation.errors {
                    errors.append("Child \(index): \(error)")
                }
                for warning in childValidation.warnings {
                    warnings.append("Child \(index): \(warning)")
                }
            }
        }
        
        return SplitValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
    
    public enum SplitDirection: String, CaseIterable, Codable, Sendable {
        case horizontal
        case vertical
        case grid // For grid splits
        
        public var displayName: String {
            switch self {
            case .horizontal: return "Horizontal"
            case .vertical: return "Vertical"
            case .grid: return "Grid"
            }
        }
        
        public var icon: String {
            switch self {
            case .horizontal: return "fluent-ic_fluent_split_horizontal_20_regular"
            case .vertical: return "fluent-ic_fluent_split_vertical_20_regular"
            case .grid: return "fluent-ic_fluent_grid_20_regular"
            }
        }
    }
    
    static let commonSplits: [SectionSplit] = [
        SectionSplit(direction: .horizontal, splitCount: 2),
        SectionSplit(direction: .vertical, splitCount: 2),
        SectionSplit(gridRows: 2, gridColumns: 2) // 2x2 grid
    ]
}

// MARK: - Validation Result

struct SplitValidationResult {
    let isValid: Bool
    let errors: [String]
    let warnings: [String]
    
    var hasErrors: Bool {
        !errors.isEmpty
    }
    
    var hasWarnings: Bool {
        !warnings.isEmpty
    }
    
    var summary: String {
        if errors.isEmpty && warnings.isEmpty {
            return "Split configuration is valid"
        } else if errors.isEmpty {
            return "Split configuration has \(warnings.count) warning(s)"
        } else {
            return "Split configuration has \(errors.count) error(s) and \(warnings.count) warning(s)"
        }
    }
}
