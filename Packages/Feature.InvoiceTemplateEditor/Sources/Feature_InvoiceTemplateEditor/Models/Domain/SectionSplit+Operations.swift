//
//  SectionSplit+Operations.swift
//  Feature.InvoiceTemplateEditor
//
//  Operations for manipulating SectionSplit structures
//

import Foundation
import Core
import SwiftUI

extension SectionSplit {
    
    // MARK: - Helpers
    
    func collectAllComponents() -> [InvoiceComponent] {
        var components: [InvoiceComponent] = []
        
        // Add components from current level
        for (_, comps) in childComponents {
            components.append(contentsOf: comps)
        }
        
        // Recursively add components from children
        for child in children {
            if let child = child {
                components.append(contentsOf: child.collectAllComponents())
            }
        }
        
        return components
    }
    
    // MARK: - Sizing Modes
    
    mutating func setWidthSizingMode(_ mode: SizingMode, forChild index: Int) {
        guard index < childWidthSizingModes.count else { return }
        childWidthSizingModes[index] = mode
    }
    
    mutating func setHeightSizingMode(_ mode: SizingMode, forChild index: Int) {
        guard index < childHeightSizingModes.count else { return }
        childHeightSizingModes[index] = mode
    }
    
    mutating func setRowSizingMode(_ mode: SizingMode, forRow index: Int) {
        guard index < rowSizingModes.count else { return }
        rowSizingModes[index] = mode
    }
    
    mutating func setColumnSizingMode(_ mode: SizingMode, forColumn index: Int) {
        guard index < columnSizingModes.count else { return }
       columnSizingModes[index] = mode
    }
    
    mutating func setChildPadding(_ value: PaddingInsets, forChild index: Int) {
        guard index < childPaddings.count else { return }
        childPaddings[index] = value
    }
    
    mutating func setChildSpacing(_ spacing: CGFloat) {
        childSpacing = max(0, spacing)
    }
    
    mutating func setPadding(_ value: CGFloat) {
        padding = max(0, value)
    }
    
    mutating func setMargin(_ value: CGFloat) {
        margin = max(0, value)
    }
}

// MARK: - Intrinsic Size Calculations

extension SectionSplit {
    
    enum LayoutAxis {
        case horizontal
        case vertical
    }
    
    /// Calculate the intrinsic size for a specific child along an axis.
    func intrinsicSizeForChild(at index: Int, along axis: LayoutAxis) -> CGFloat? {
        guard index >= 0, index < splitCount else { return nil }
        
        if let childSplit = children[index] {
            return childSplit.intrinsicSize(along: axis)
        }
        
        guard let components = childComponents[index], !components.isEmpty else {
            return nil
        }
        
        return intrinsicSize(forLeafComponents: components, along: axis)
    }
    
    /// Calculate the intrinsic size of this split along an axis, aggregating its children.
    func intrinsicSize(along axis: LayoutAxis) -> CGFloat? {
        switch direction {
        case .horizontal:
            if axis == .horizontal {
                let total = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .horizontal) }
                    .reduce(0, +)
                return total > 0 ? total : nil
            } else {
                let maxHeight = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .vertical) }
                    .max() ?? 0
                return maxHeight > 0 ? maxHeight : nil
            }
        case .vertical:
            if axis == .horizontal {
                let maxWidth = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .horizontal) }
                    .max() ?? 0
                return maxWidth > 0 ? maxWidth : nil
            } else {
                let total = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .vertical) }
                    .reduce(0, +)
                return total > 0 ? total : nil
            }
        case .grid:
            if axis == .horizontal {
                var totalWidth: CGFloat = 0
                for column in 0..<gridColumns {
                    var maxColumnWidth: CGFloat = 0
                    for row in 0..<gridRows {
                        let cellIndex = cellIndex(row: row, column: column)
                        let cellWidth = intrinsicSizeForChild(at: cellIndex, along: .horizontal) ?? 0
                        maxColumnWidth = max(maxColumnWidth, cellWidth)
                    }
                    totalWidth += maxColumnWidth
                }
                return totalWidth > 0 ? totalWidth : nil
            } else {
                var totalHeight: CGFloat = 0
                for row in 0..<gridRows {
                    var maxRowHeight: CGFloat = 0
                    for column in 0..<gridColumns {
                        let cellIndex = cellIndex(row: row, column: column)
                        let cellHeight = intrinsicSizeForChild(at: cellIndex, along: .vertical) ?? 0
                        maxRowHeight = max(maxRowHeight, cellHeight)
                    }
                    totalHeight += maxRowHeight
                }
                return totalHeight > 0 ? totalHeight : nil
            }
        }
    }
    
    private func intrinsicSize(forLeafComponents components: [InvoiceComponent], along axis: LayoutAxis) -> CGFloat? {
        guard !components.isEmpty else { return nil }
        switch axis {
        case .horizontal:
            let width = components.map { $0.size.width }.max() ?? 0
            return width > 0 ? width : nil
        case .vertical:
            let height = components.reduce(0) { $0 + $1.size.height }
            return height > 0 ? height : nil
        }
    }
}
