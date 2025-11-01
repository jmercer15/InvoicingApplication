//
//  SplittableRectangleView.swift
//  Feature.InvoiceTemplateEditor
//
//  Recursive view for rendering splittable sections with nested splits
//

import SwiftUI
import Core

struct SplittableRectangleView: View {
    let split: SectionSplit?
    let leafComponents: [InvoiceComponent] // Components for leaf sections (when split == nil)
    let containerSize: CGSize
    let childIndex: Int
    let onDrop: (NSItemProvider, CGPoint) -> Bool
    let onSplitChild: (Int, SectionSplit.SplitDirection, Int, Int?, Int?) -> Void
    let onUnsplitChild: (Int) -> Void
    let onResize: (Int, CGFloat) -> Void
    let onUpdateSplit: (SectionSplit) -> Void
    let onAddComponent: (Int, InvoiceComponent) -> Void // Changed to include childIndex
    let onSetLabel: ((Int, String?) -> Void)? // New: for setting section labels
    let onReorderChildren: ((Int, Int) -> Void)? // New: for reordering sections
    let onComponentSelect: (InvoiceComponent) -> Void // New: for component selection
    
    @State private var isHovered = false
    @State private var showingSplitMenu = false
    @State private var showingSplitDialog = false
    @State private var selectedSplitDirection: SectionSplit.SplitDirection = .horizontal
    @State private var splitCount: Int = 2
    
    init(split: SectionSplit?, leafComponents: [InvoiceComponent] = [], containerSize: CGSize, childIndex: Int = 0, onDrop: @escaping (NSItemProvider, CGPoint) -> Bool, onSplitChild: @escaping (Int, SectionSplit.SplitDirection, Int, Int?, Int?) -> Void, onUnsplitChild: @escaping (Int) -> Void, onResize: @escaping (Int, CGFloat) -> Void, onUpdateSplit: @escaping (SectionSplit) -> Void, onAddComponent: @escaping (Int, InvoiceComponent) -> Void, onSetLabel: ((Int, String?) -> Void)? = nil, onReorderChildren: ((Int, Int) -> Void)? = nil, onComponentSelect: @escaping (InvoiceComponent) -> Void) {
        self.split = split
        self.leafComponents = leafComponents
        self.containerSize = containerSize
        self.childIndex = childIndex
        self.onDrop = onDrop
        self.onSplitChild = onSplitChild
        self.onUnsplitChild = onUnsplitChild
        self.onResize = onResize
        self.onUpdateSplit = onUpdateSplit
        self.onAddComponent = onAddComponent
        self.onSetLabel = onSetLabel
        self.onReorderChildren = onReorderChildren
        self.onComponentSelect = onComponentSelect
    }
    
    var body: some View {
        Group {
            if let split = split {
                let _ = print("   🔍 SplittableRectangleView rendering with split: \(split.id)")
                let _ = print("      Split has \(split.childComponents.count) child component arrays")
                let _ = print("      Split direction: \(split.direction), children: \(split.children.count)")
                
                // Render split subsections based on direction
                switch split.direction {
                case .horizontal:
                    RatioBasedLayout(ratios: split.splitRatios, direction: .horizontal, containerSize: containerSize, onResize: onResize) { subIndex, containerSize in
                        GeometryReader { geometry in
                            SplittableRectangleView(
                                split: split.children[subIndex],
                                leafComponents: split.childComponents[subIndex] ?? [],
                                containerSize: geometry.size,
                                childIndex: subIndex,
                                onDrop: onDrop,
                                onSplitChild: { childIndex, direction, count, rows, columns in
                                    // Handle split locally at this level
                                    var updatedSplit = split
                                    if direction == .grid, let rows = rows, let columns = columns {
                                        updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows, gridColumns: columns)
                                    } else {
                                        updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count)
                                    }
                                    onUpdateSplit(updatedSplit)
                                },
                                onUnsplitChild: { childIndex in
                                    // Handle unsplit locally at this level
                                    var updatedSplit = split
                                    updatedSplit.unsplitChild(at: childIndex)
                                    onUpdateSplit(updatedSplit)
                                },
                                onResize: { childIndex, delta in
                                    // Handle nested resize within horizontal split
                                    print("Horizontal nested resize: childIndex=\(childIndex), delta=\(delta), subIndex=\(subIndex)")
                                    var updatedSplit = split
                                    
                                    // Determine which dimension this nested split controls
                                    if let childSplit = split.children[subIndex] {
                                        switch childSplit.direction {
                                        case .horizontal:
                                            // Horizontal split controls width within this horizontal container
                                            let containerWidth = containerSize.width
                                            let ratioChange = delta / containerWidth
                                            
                                            let currentRatio = childSplit.splitRatios[childIndex]
                                            let nextRatio = childSplit.splitRatios[childIndex + 1]
                                            
                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))
                                            
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex] = newCurrentRatio
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex + 1] = newNextRatio
                                            
                                        case .vertical:
                                            // Vertical split controls height within this horizontal container
                                            let containerHeight = containerSize.height
                                            let ratioChange = delta / containerHeight
                                            
                                            let currentRatio = childSplit.splitRatios[childIndex]
                                            let nextRatio = childSplit.splitRatios[childIndex + 1]
                                            
                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))
                                            
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex] = newCurrentRatio
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex + 1] = newNextRatio
                                            
                                        case .grid:
                                            // Nested grid - this shouldn't happen in practice
                                            break
                                        }
                                    }
                                    
                                    onUpdateSplit(updatedSplit)
                                },
                                onUpdateSplit: { updatedChildSplit in
                                    var updatedSplit = split
                                    updatedSplit.children[subIndex] = updatedChildSplit
                                    onUpdateSplit(updatedSplit)
                                },
                                onAddComponent: { childIdx, component in
                                    print("   🔀 Horizontal split: onAddComponent received for child \(childIdx) in subIndex \(subIndex)")
                                    print("   🔀 Updating MY child \(subIndex) with component for its child \(childIdx)...")
                                    
                                    var updatedSplit = split
                                    
                                    // If my child has a split, add to that child's components
                                    if var childSplit = updatedSplit.children[subIndex] {
                                        childSplit.addComponent(component, toChild: childIdx)
                                        updatedSplit.children[subIndex] = childSplit
                                    } else {
                                        // My child is a leaf, add directly to my childComponents for that child
                                        updatedSplit.addComponent(component, toChild: subIndex)
                                    }
                                    
                                    onUpdateSplit(updatedSplit)
                                    print("   ✅ Horizontal split: Updated child \(subIndex)")
                                },
                                onComponentSelect: onComponentSelect
                            )
                        }
                    }
                case .vertical:
                    RatioBasedLayout(ratios: split.splitRatios, direction: .vertical, containerSize: containerSize, onResize: onResize) { subIndex, containerSize in
                        GeometryReader { geometry in
                            SplittableRectangleView(
                                split: split.children[subIndex],
                                leafComponents: split.childComponents[subIndex] ?? [],
                                containerSize: geometry.size,
                                childIndex: subIndex,
                                onDrop: onDrop,
                                onSplitChild: { childIndex, direction, count, rows, columns in
                                    // Handle split locally at this level
                                    var updatedSplit = split
                                    if direction == .grid, let rows = rows, let columns = columns {
                                        updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows, gridColumns: columns)
                                    } else {
                                        updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count)
                                    }
                                    onUpdateSplit(updatedSplit)
                                },
                                onUnsplitChild: { childIndex in
                                    // Handle unsplit locally at this level
                                    var updatedSplit = split
                                    updatedSplit.unsplitChild(at: childIndex)
                                    onUpdateSplit(updatedSplit)
                                },
                                onResize: { childIndex, delta in
                                    // Handle nested resize within vertical split
                                    print("Vertical nested resize: childIndex=\(childIndex), delta=\(delta), subIndex=\(subIndex)")
                                    var updatedSplit = split
                                    
                                    // Determine which dimension this nested split controls
                                    if let childSplit = split.children[subIndex] {
                                        switch childSplit.direction {
                                        case .horizontal:
                                            // Horizontal split controls width within this vertical container
                                            let containerWidth = containerSize.width
                                            let ratioChange = delta / containerWidth
                                            
                                            let currentRatio = childSplit.splitRatios[childIndex]
                                            let nextRatio = childSplit.splitRatios[childIndex + 1]
                                            
                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))
                                            
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex] = newCurrentRatio
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex + 1] = newNextRatio
                                            
                                        case .vertical:
                                            // Vertical split controls height within this vertical container
                                            let containerHeight = containerSize.height
                                            let ratioChange = delta / containerHeight
                                            
                                            let currentRatio = childSplit.splitRatios[childIndex]
                                            let nextRatio = childSplit.splitRatios[childIndex + 1]
                                            
                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))
                                            
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex] = newCurrentRatio
                                            updatedSplit.children[subIndex]?.splitRatios[childIndex + 1] = newNextRatio
                                            
                                        case .grid:
                                            // Nested grid - this shouldn't happen in practice
                                            break
                                        }
                                    }
                                    
                                    onUpdateSplit(updatedSplit)
                                },
                                onUpdateSplit: { updatedChildSplit in
                                    var updatedSplit = split
                                    updatedSplit.children[subIndex] = updatedChildSplit
                                    onUpdateSplit(updatedSplit)
                                },
                                onAddComponent: { childIdx, component in
                                    print("   🔀 Vertical split: onAddComponent received for child \(childIdx) in subIndex \(subIndex)")
                                    print("   🔀 Updating MY child \(subIndex) with component for its child \(childIdx)...")
                                    
                                    var updatedSplit = split
                                    
                                    // If my child has a split, add to that child's components
                                    if var childSplit = updatedSplit.children[subIndex] {
                                        childSplit.addComponent(component, toChild: childIdx)
                                        updatedSplit.children[subIndex] = childSplit
                                    } else {
                                        // My child is a leaf, add directly to my childComponents for that child
                                        updatedSplit.addComponent(component, toChild: subIndex)
                                    }
                                    
                                    onUpdateSplit(updatedSplit)
                                    print("   ✅ Vertical split: Updated child \(subIndex)")
                                },
                                onComponentSelect: onComponentSelect
                            )
                        }
                    }
                case .grid:
                    // For grid, we create a proper grid layout with separate height and width ratios
                    ZStack {
                        // Main content layout
                        VStack(spacing: 0) {
                            ForEach(0..<split.gridRows, id: \.self) { rowIndex in
                                HStack(spacing: 0) {
                                    ForEach(0..<split.gridColumns, id: \.self) { columnIndex in
                                        let cellIndex = split.cellIndex(row: rowIndex, column: columnIndex)
                                        
                                        GeometryReader { geometry in
                                            ZStack {
                                                // Cell background with subtle border
                                                Rectangle()
                                                    .fill(Color.clear)
                                                    .overlay(
                                                        Rectangle()
                                                            .stroke(Color.accentColor.opacity(0.2), lineWidth: 0.5)
                                                    )
                                                
                                                SplittableRectangleView(
                                                split: split.children[cellIndex],
                                                leafComponents: split.childComponents[cellIndex] ?? [],
                                                containerSize: geometry.size,
                                                childIndex: cellIndex,
                                                onDrop: onDrop,
                                                    onSplitChild: { childIndex, direction, count, rows, columns in
                                                        // Handle split locally at this level
                                                        var updatedSplit = split
                                                        if direction == .grid, let rows = rows, let columns = columns {
                                                            updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows, gridColumns: columns)
                                                        } else {
                                                            updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count)
                                                        }
                                                        onUpdateSplit(updatedSplit)
                                                    },
                                                    onUnsplitChild: { childIndex in
                                                        // Handle unsplit locally at this level
                                                        var updatedSplit = split
                                                        updatedSplit.unsplitChild(at: childIndex)
                                                        onUpdateSplit(updatedSplit)
                                                    },
                                                onResize: { childIndex, delta in
                                                    // Handle nested resize within grid cell
                                                    print("Grid nested resize: childIndex=\(childIndex), delta=\(delta), cellIndex=\(cellIndex)")
                                                    var updatedSplit = split
                                                    
                                                    // Determine which dimension this nested split controls
                                                    if let childSplit = split.children[cellIndex] {
                                                        switch childSplit.direction {
                                                        case .horizontal:
                                                            // Horizontal split controls width within this cell
                                                            let cellWidth = containerSize.width * split.widthRatios[columnIndex]
                                                            let ratioChange = delta / cellWidth
                                                            
                                                            let currentRatio = childSplit.splitRatios[childIndex]
                                                            let nextRatio = childSplit.splitRatios[childIndex + 1]
                                                            
                                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))
                                                            
                                                            updatedSplit.children[cellIndex]?.splitRatios[childIndex] = newCurrentRatio
                                                            updatedSplit.children[cellIndex]?.splitRatios[childIndex + 1] = newNextRatio
                                                            
                                                        case .vertical:
                                                            // Vertical split controls height within this cell
                                                            let cellHeight = containerSize.height * split.heightRatios[rowIndex]
                                                            let ratioChange = delta / cellHeight
                                                            
                                                            let currentRatio = childSplit.splitRatios[childIndex]
                                                            let nextRatio = childSplit.splitRatios[childIndex + 1]
                                                            
                                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))
                                                            
                                                            updatedSplit.children[cellIndex]?.splitRatios[childIndex] = newCurrentRatio
                                                            updatedSplit.children[cellIndex]?.splitRatios[childIndex + 1] = newNextRatio
                                                            
                                                        case .grid:
                                                            // Nested grid - this shouldn't happen in practice
                                                            break
                                                        }
                                                    }
                                                    
                                                    onUpdateSplit(updatedSplit)
                                                },
                                                onUpdateSplit: { updatedChildSplit in
                                                    var updatedSplit = split
                                                    updatedSplit.children[cellIndex] = updatedChildSplit
                                                    onUpdateSplit(updatedSplit)
                                                },
                                                onAddComponent: { childIdx, component in
                                                    print("   🔀 Grid split: onAddComponent received for child \(childIdx) in cellIndex \(cellIndex)")
                                                    print("   🔀 Updating MY child \(cellIndex) with component for its child \(childIdx)...")
                                                    
                                                    var updatedSplit = split
                                                    
                                                    // If my child has a split, add to that child's components
                                                    if var childSplit = updatedSplit.children[cellIndex] {
                                                        childSplit.addComponent(component, toChild: childIdx)
                                                        updatedSplit.children[cellIndex] = childSplit
                                                    } else {
                                                        // My child is a leaf, add directly to my childComponents for that child
                                                        updatedSplit.addComponent(component, toChild: cellIndex)
                                                    }
                                                    
                                                    onUpdateSplit(updatedSplit)
                                                    print("   ✅ Grid split: Updated child \(cellIndex)")
                                                },
                                                onComponentSelect: onComponentSelect
                                            )
                                            }
                                        }
                                        .frame(width: containerSize.width * split.widthRatios[columnIndex])
                                        .frame(height: containerSize.height * split.heightRatios[rowIndex])
                                    }
                                }
                            }
                        }
                        
                        // Overlay dividers using alignment
                        VStack(spacing: 0) {
                            ForEach(0..<split.gridRows, id: \.self) { rowIndex in
                                HStack(spacing: 0) {
                                    ForEach(0..<split.gridColumns, id: \.self) { columnIndex in
                                        Rectangle()
                                            .fill(Color.clear)
                                            .frame(width: containerSize.width * split.widthRatios[columnIndex])
                                            .frame(height: containerSize.height * split.heightRatios[rowIndex])
                                            .overlay(alignment: .trailing) {
                                                if columnIndex < split.gridColumns - 1 {
                                                    ResizableDivider(
                                                        direction: .horizontal,
                                                        onResize: { delta in
                                                            // Handle horizontal resize logic for grid
                                                            print("Grid horizontal resize: delta=\(delta), columnIndex=\(columnIndex)")
                                                            var updatedSplit = split
                                                            let containerWidth = containerSize.width
                                                            let ratioChange = delta / containerWidth

                                                            let currentRatio = updatedSplit.widthRatios[columnIndex]
                                                            let nextRatio = updatedSplit.widthRatios[columnIndex + 1]

                                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))

                                                            updatedSplit.widthRatios[columnIndex] = newCurrentRatio
                                                            updatedSplit.widthRatios[columnIndex + 1] = newNextRatio

                                                            print("Updated width ratios: \(updatedSplit.widthRatios)")
                                                            onUpdateSplit(updatedSplit)
                                                        }
                                                    )
                                                }
                                            }
                                            .overlay(alignment: .bottom) {
                                                if rowIndex < split.gridRows - 1 {
                                                    ResizableDivider(
                                                        direction: .vertical,
                                                        onResize: { delta in
                                                            // Handle vertical resize logic for grid
                                                            print("Grid vertical resize: delta=\(delta), rowIndex=\(rowIndex)")
                                                            var updatedSplit = split
                                                            let containerHeight = containerSize.height
                                                            let ratioChange = delta / containerHeight

                                                            let currentRatio = updatedSplit.heightRatios[rowIndex]
                                                            let nextRatio = updatedSplit.heightRatios[rowIndex + 1]

                                                            let newCurrentRatio = max(0.05, min(0.95, currentRatio + ratioChange))
                                                            let newNextRatio = max(0.05, min(0.95, nextRatio - ratioChange))

                                                            updatedSplit.heightRatios[rowIndex] = newCurrentRatio
                                                            updatedSplit.heightRatios[rowIndex + 1] = newNextRatio

                                                            print("Updated height ratios: \(updatedSplit.heightRatios)")
                                                            onUpdateSplit(updatedSplit)
                                                        }
                                                    )
                                                }
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .onAppear {
                        print("Grid container size: \(containerSize)")
                        print("Grid rows: \(split.gridRows), columns: \(split.gridColumns)")
                        print("Height ratios: \(split.heightRatios)")
                        print("Width ratios: \(split.widthRatios)")
                        print("Expected cell sizes:")
                        for row in 0..<split.gridRows {
                            for col in 0..<split.gridColumns {
                                let cellIndex = split.cellIndex(row: row, column: col)
                                let width = containerSize.width * split.widthRatios[col]
                                let height = containerSize.height * split.heightRatios[row]
                                print("  Cell \(cellIndex) (\(row),\(col)): \(width)x\(height)")
                            }
                        }
                    }
                }
            } else {
                let _ = print("   🔍 SplittableRectangleView: NO SPLIT (leaf node)")
                let _ = print("      leafComponents.count: \(leafComponents.count)")
                
                // Leaf node - content area
                ContentRectangleView(
                    components: leafComponents,
                    containerSize: containerSize,
                    sectionLabel: nil, // TODO: Get label from parent split
                    onAddComponent: { component in
                        // Leaf node - pass childIndex with component
                        onAddComponent(childIndex, component)
                    },
                    onSplit: { direction, count, rows, columns in
                        // Call the parent's split child callback with the correct child index
                        if direction == .grid, let rows = rows, let columns = columns {
                            onSplitChild(childIndex, direction, count, rows, columns)
                        } else {
                            onSplitChild(childIndex, direction, count, nil, nil)
                        }
                    },
                    onSetLabel: { label in
                        onSetLabel?(childIndex, label)
                    },
                    onComponentSelect: { component in
                        onComponentSelect(component)
                    }
                )
            }
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
        .animation(.easeInOut(duration: 0.25), value: split?.id)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .onKeyPress(.space) {
            if split == nil {
                selectedSplitDirection = .horizontal
                splitCount = 2
                showingSplitDialog = true
            }
            return .handled
        }
        .onKeyPress(.init("h")) {
            if split == nil {
                selectedSplitDirection = .horizontal
                splitCount = 2
                showingSplitDialog = true
            }
            return .handled
        }
        .onKeyPress(.init("v")) {
            if split == nil {
                selectedSplitDirection = .vertical
                splitCount = 2
                showingSplitDialog = true
            }
            return .handled
        }
        .onKeyPress(.init("g")) {
            if split == nil {
                selectedSplitDirection = .grid
                splitCount = 4
                showingSplitDialog = true
            }
            return .handled
        }
        .onKeyPress(.delete) {
            if split != nil {
                onUnsplitChild(childIndex)
            }
            return .handled
        }
        .contextMenu {
            ForEach(SectionSplit.commonSplits, id: \.id) { splitOption in
                Button(action: {
                    selectedSplitDirection = splitOption.direction
                    splitCount = splitOption.splitCount
                    showingSplitDialog = true
                }) {
                    Label(splitOption.direction.displayName, systemImage: splitOption.direction.icon)
                }
            }
            
            if split != nil {
                Divider()
                Button("Remove Split", role: .destructive) {
                    onUnsplitChild(childIndex)
                }
            }
        }
        .confirmationDialog("Split Section", isPresented: $showingSplitMenu) {
            ForEach(SectionSplit.commonSplits, id: \.id) { splitOption in
                Button(splitOption.direction.displayName) {
                    selectedSplitDirection = splitOption.direction
                    splitCount = splitOption.splitCount
                    showingSplitDialog = true
                }
            }
            
            if split != nil {
                Button("Remove Split", role: .destructive) {
                    onUnsplitChild(childIndex)
                }
            }
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showingSplitDialog) {
                SplitConfigurationDialog(
                    direction: $selectedSplitDirection,
                    splitCount: $splitCount,
                    onConfirm: { direction, count, rows, columns in
                        if direction == .grid, let rows = rows, let columns = columns {
                            // Create a custom grid split with the specified dimensions
                            if var updatedSplit = split {
                                updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows, gridColumns: columns)
                                onUpdateSplit(updatedSplit)
                            }
                        } else {
                            onSplitChild(childIndex, direction, count, nil, nil)
                        }
                        showingSplitDialog = false
                    },
                    onCancel: {
                        showingSplitDialog = false
                    }
                )
        }
    }
}
