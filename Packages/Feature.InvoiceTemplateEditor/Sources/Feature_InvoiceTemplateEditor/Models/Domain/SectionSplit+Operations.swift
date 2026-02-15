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
    
    mutating func setUniformChildPadding(_ value: CGFloat, forChild index: Int) {
        guard index < childPaddings.count else { return }
        childPaddings[index] = PaddingInsets(top: value, leading: value, bottom: value, trailing: value)
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
        
        var contentSize: CGFloat?
        var marginAmount: CGFloat = 0
        
        if let childSplit = children[index] {
            contentSize = childSplit.intrinsicSize(along: axis)
            marginAmount = childSplit.margin * 2
        } else if let components = childComponents[index], !components.isEmpty {
            contentSize = intrinsicSize(forLeafComponents: components, along: axis)
        }
        
        guard let size = contentSize else { return nil }
        
        let padding = childPaddings.count > index ? childPaddings[index] : .zero
        let paddingAmount = axis == .horizontal ? (padding.leading + padding.trailing) : (padding.top + padding.bottom)
        
        return size + paddingAmount + marginAmount
    }
    
    /// Calculate the intrinsic size of this split along an axis, aggregating its children.
    func intrinsicSize(along axis: LayoutAxis) -> CGFloat? {
        let paddingAmount = axis == .horizontal ? (padding * 2) : (padding * 2) // Padding applies to both axes (all sides)
        // Note: padding property is a single CGFloat applied to all sides
        
        switch direction {
        case .horizontal:
            if axis == .horizontal {
                let childrenSizes = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .horizontal) }
                
                if childrenSizes.isEmpty { return nil }
                
                let total = childrenSizes.reduce(0, +)
                let spacingTotal = childSpacing * CGFloat(max(0, childrenSizes.count - 1))
                
                return total + spacingTotal + paddingAmount
            } else {
                let maxHeight = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .vertical) }
                    .max() ?? 0
                return maxHeight > 0 ? maxHeight + paddingAmount : nil
            }
        case .vertical:
            if axis == .horizontal {
                let maxWidth = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .horizontal) }
                    .max() ?? 0
                return maxWidth > 0 ? maxWidth + paddingAmount : nil
            } else {
                let childrenSizes = (0..<splitCount)
                    .compactMap { intrinsicSizeForChild(at: $0, along: .vertical) }
                
                if childrenSizes.isEmpty { return nil }
                
                let total = childrenSizes.reduce(0, +)
                let spacingTotal = childSpacing * CGFloat(max(0, childrenSizes.count - 1))
                
                return total + spacingTotal + paddingAmount
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
                // Grid spacing logic might be more complex, assuming simple spacing for now
                // Actually grid usually has spacing between columns
                let spacingTotal = childSpacing * CGFloat(max(0, gridColumns - 1))
                return totalWidth > 0 ? totalWidth + spacingTotal + paddingAmount : nil
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
                let spacingTotal = childSpacing * CGFloat(max(0, gridRows - 1))
                return totalHeight > 0 ? totalHeight + spacingTotal + paddingAmount : nil
            }
        }
    }
    
    private func intrinsicSize(forLeafComponents components: [InvoiceComponent], along axis: LayoutAxis) -> CGFloat? {
        // ContentRectangleView only renders the first component, so we should only measure the first one.
        guard let component = components.first else { return nil }
        
        switch axis {
        case .horizontal:
            if let minWidth = component.minIntrinsicWidth {
                return minWidth
            }
            // Use idealSize if available, otherwise fallback to size
            if let idealWidth = component.idealSize?.width, idealWidth > 0 {
                return idealWidth
            }
            return component.size.width > 0 ? component.size.width : nil
        case .vertical:
            if let minHeight = component.minIntrinsicHeight {
                return minHeight
            }
            // Use idealSize if available, otherwise fallback to size
            if let idealHeight = component.idealSize?.height, idealHeight > 0 {
                return idealHeight
            }
            return component.size.height > 0 ? component.size.height : nil
        }
    }
}
