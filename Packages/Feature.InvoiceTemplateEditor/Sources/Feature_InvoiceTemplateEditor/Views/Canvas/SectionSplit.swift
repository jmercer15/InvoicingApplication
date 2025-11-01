//
//  SectionSplit.swift
//  Feature.InvoiceTemplateEditor
//
//  Model for representing a split section with nested subsections
//

import Foundation
import Core

/// Model representing a split section that can be recursively subdivided
struct SectionSplit {
    let direction: SplitDirection
    let splitCount: Int
    var splitRatios: [CGFloat] // For custom sizing - now mutable
    var children: [SectionSplit?] // Nested subsections
    var childComponents: [Int: [InvoiceComponent]] = [:] // Components per child index (for leaf children)
    var childLabels: [Int: String] = [:] // Labels for each child section
    let id: UUID
    
    // Grid-specific properties
    var gridRows: Int = 2
    var gridColumns: Int = 2
    var heightRatios: [CGFloat] = [] // For grid: row height ratios
    var widthRatios: [CGFloat] = [] // For grid: column width ratios
    
    init(direction: SplitDirection, splitCount: Int, splitRatios: [CGFloat]? = nil) {
        self.direction = direction
        self.splitCount = splitCount
        self.id = UUID()
        
        if let ratios = splitRatios, ratios.count == splitCount {
            self.splitRatios = ratios
        } else {
            // Default equal ratios
            self.splitRatios = Array(repeating: 1.0 / CGFloat(splitCount), count: splitCount)
        }
        
        // Initialize children as nil (unsplit)
        self.children = Array(repeating: nil, count: splitCount)
        
        // Initialize grid-specific properties
        if direction == .grid {
            self.gridRows = 2
            self.gridColumns = 2
            self.heightRatios = Array(repeating: 1.0 / CGFloat(gridRows), count: gridRows)
            self.widthRatios = Array(repeating: 1.0 / CGFloat(gridColumns), count: gridColumns)
        }
    }
    
    // Grid-specific initializer
    init(gridRows: Int, gridColumns: Int, heightRatios: [CGFloat]? = nil, widthRatios: [CGFloat]? = nil) {
        self.direction = .grid
        self.splitCount = gridRows * gridColumns
        self.id = UUID()
        self.gridRows = gridRows
        self.gridColumns = gridColumns
        
        // Initialize children as nil (unsplit)
        self.children = Array(repeating: nil, count: splitCount)
        
        // Set height ratios
        if let ratios = heightRatios, ratios.count == gridRows {
            self.heightRatios = ratios
        } else {
            self.heightRatios = Array(repeating: 1.0 / CGFloat(gridRows), count: gridRows)
        }
        
        // Set width ratios
        if let ratios = widthRatios, ratios.count == gridColumns {
            self.widthRatios = ratios
        } else {
            self.widthRatios = Array(repeating: 1.0 / CGFloat(gridColumns), count: gridColumns)
        }
        
        // Legacy splitRatios for compatibility (not used for grid)
        self.splitRatios = Array(repeating: 1.0 / CGFloat(splitCount), count: splitCount)
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
    
    // Component management methods
    mutating func addComponent(_ component: InvoiceComponent, toChild childIndex: Int) {
        print("   🔧 SectionSplit.addComponent: Adding component \(component.id) to child \(childIndex)")
        var components = childComponents[childIndex] ?? []
        print("      Child \(childIndex) components before: \(components.count)")
        
        // Check if component already exists to prevent duplicates
        if components.contains(where: { $0.id == component.id }) {
            print("      ⚠️ Component \(component.id) already exists in child \(childIndex), skipping duplicate")
            return
        }
        
        components.append(component)
        childComponents[childIndex] = components
        print("      Child \(childIndex) components after: \(components.count)")
        print("      Child \(childIndex) component IDs: \(components.map { $0.id })")
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
            return "Section \(childIndex + 1)"
        case .vertical:
            return "Row \(childIndex + 1)"
        case .grid:
            let (row, column) = rowColumn(for: childIndex)
            return "Cell \(row + 1),\(column + 1)"
        }
    }
    
    /// Remove a label for a specific child section
    mutating func removeLabel(forChild childIndex: Int) {
        childLabels.removeValue(forKey: childIndex)
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
    
    enum SplitDirection: CaseIterable {
        case horizontal
        case vertical
        case grid // For grid splits
        
        var displayName: String {
            switch self {
            case .horizontal: return "Horizontal"
            case .vertical: return "Vertical"
            case .grid: return "Grid"
            }
        }
        
        var icon: String {
            switch self {
            case .horizontal: return "rectangle.split.1x2"
            case .vertical: return "rectangle.split.2x1"
            case .grid: return "rectangle.split.2x2"
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

