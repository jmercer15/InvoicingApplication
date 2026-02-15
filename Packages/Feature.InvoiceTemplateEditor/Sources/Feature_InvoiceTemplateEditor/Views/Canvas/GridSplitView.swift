//
//  GridSplitView.swift
//  Feature.InvoiceTemplateEditor
//
//  View for rendering grid splits
//

import SwiftUI
import Core

struct GridSplitView: View {
    let split: SectionSplit
    let containerSize: CGSize
    let sectionIndex: Int
    let nodePath: [Int]
    let context: SplitInteractionContext

    var body: some View {
        let spacing = max(0, split.childSpacing)
        let padding = max(0, split.padding)
        let availableWidth = max(0, containerSize.width - (padding * 2) - (spacing * CGFloat(max(0, split.gridColumns - 1))))
        let availableHeight = max(0, containerSize.height - (padding * 2) - (spacing * CGFloat(max(0, split.gridRows - 1))))
        // Calculate intrinsic sizes for rows and columns
        let rowIntrinsicSizes: [Int: CGFloat] = {
            var sizes: [Int: CGFloat] = [:]
            for rowIndex in 0..<split.gridRows {
                var maxHeight: CGFloat = 0
                for columnIndex in 0..<split.gridColumns {
                    let cellIndex = split.cellIndex(row: rowIndex, column: columnIndex)
                    let height = split.intrinsicSizeForChild(at: cellIndex, along: .vertical) ?? 0
                    maxHeight = max(maxHeight, height)
                }
                if maxHeight > 0 {
                    sizes[rowIndex] = maxHeight
                }
            }
            return sizes
        }()
        
        let columnIntrinsicSizes: [Int: CGFloat] = {
            var sizes: [Int: CGFloat] = [:]
            for columnIndex in 0..<split.gridColumns {
                var maxWidth: CGFloat = 0
                for rowIndex in 0..<split.gridRows {
                    let cellIndex = split.cellIndex(row: rowIndex, column: columnIndex)
                    let width = split.intrinsicSizeForChild(at: cellIndex, along: .horizontal) ?? 0
                    maxWidth = max(maxWidth, width)
                }
                if maxWidth > 0 {
                    sizes[columnIndex] = maxWidth
                }
            }
            return sizes
        }()
        
        let columnWidths = FlexibleSizeCalculator.calculateSizes(
            totalSize: availableWidth,
            count: split.gridColumns,
            ratios: split.widthRatios,
            sizingModes: split.columnSizingModes,
            intrinsicSizes: columnIntrinsicSizes
        )
        
        let rowHeights = FlexibleSizeCalculator.calculateSizes(
            totalSize: availableHeight,
            count: split.gridRows,
            ratios: split.heightRatios,
            sizingModes: split.rowSizingModes,
            intrinsicSizes: rowIntrinsicSizes
        )
        
        ZStack {
            VStack(spacing: spacing) {
                ForEach(Array(0..<split.gridRows), id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(Array(0..<split.gridColumns), id: \.self) { columnIndex in
                            let cellIndex = split.cellIndex(row: rowIndex, column: columnIndex)
                            let childSize = CGSize(width: columnWidths[columnIndex], height: rowHeights[rowIndex])
                            let childPadding = split.childPaddings.count > cellIndex ? split.childPaddings[cellIndex] : .zero
                            
                            SplittableRectangleView(
                                split: split.children[cellIndex],
                                leafComponents: split.childComponents[cellIndex] ?? [],
                                containerSize: childSize,
                                sectionIndex: sectionIndex,
                                nodePath: nodePath + [cellIndex],
                                childIndex: cellIndex,
                                childPadding: childPadding,
                                parentAlignment: split.getAlignment(forChild: cellIndex),
                                context: makeChildContext(for: cellIndex)
                            )
                            .frame(width: childSize.width, height: childSize.height)
                        }
                    }
                }
            }
            
            // Grid Dividers
            VStack(spacing: spacing) {
                ForEach(Array(0..<split.gridRows), id: \.self) { rowIndex in
                    HStack(spacing: spacing) {
                        ForEach(Array(0..<split.gridColumns), id: \.self) { columnIndex in
                            Rectangle()
                                .fill(Color.clear)
                                .frame(width: columnWidths[columnIndex])
                                .frame(height: rowHeights[rowIndex])
                                .overlay(alignment: .trailing) {
                                    if columnIndex < split.gridColumns - 1 {
                                        ResizableDivider(direction: .horizontal, onResize: { delta in
                                            var updatedSplit = split
                                            
                                            // Switch to fixed mode on resize
                                            updatedSplit.setColumnSizingMode(.fixed, forColumn: columnIndex)
                                            updatedSplit.setColumnSizingMode(.fixed, forColumn: columnIndex + 1)
                                            
                                            let width = max(0, containerSize.width - (padding * 2) - (spacing * CGFloat(max(0, split.gridColumns - 1))))
                                            let (newCurrentRatio, newNextRatio) = safeResizeRatios(
                                                delta: delta,
                                                containerSize: width,
                                                currentRatio: updatedSplit.widthRatios[columnIndex],
                                                nextRatio: updatedSplit.widthRatios[columnIndex + 1]
                                            )
                                            updatedSplit.widthRatios[columnIndex] = newCurrentRatio
                                            updatedSplit.widthRatios[columnIndex + 1] = newNextRatio
                                            context.onUpdateSplit(updatedSplit, nil)
                                        }, onResizeStart: {
                                            context.onResizeStart?(sectionIndex)
                                        }, isVisible: context.showDividers)
                                    }
                                }
                                .overlay(alignment: .bottom) {
                                    if rowIndex < split.gridRows - 1 {
                                        ResizableDivider(direction: .vertical, onResize: { delta in
                                            var updatedSplit = split
                                            
                                            // Switch to fixed mode on resize
                                            updatedSplit.setRowSizingMode(.fixed, forRow: rowIndex)
                                            updatedSplit.setRowSizingMode(.fixed, forRow: rowIndex + 1)
                                            
                                            let height = max(0, containerSize.height - (padding * 2) - (spacing * CGFloat(max(0, split.gridRows - 1))))
                                            let (newCurrentRatio, newNextRatio) = safeResizeRatios(
                                                delta: delta,
                                                containerSize: height,
                                                currentRatio: updatedSplit.heightRatios[rowIndex],
                                                nextRatio: updatedSplit.heightRatios[rowIndex + 1]
                                            )
                                            updatedSplit.heightRatios[rowIndex] = newCurrentRatio
                                            updatedSplit.heightRatios[rowIndex + 1] = newNextRatio
                                            context.onUpdateSplit(updatedSplit, nil)
                                        }, onResizeStart: {
                                            context.onResizeStart?(sectionIndex)
                                        }, isVisible: context.showDividers)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .padding(padding)
    }
    
    private func makeChildContext(for index: Int) -> SplitInteractionContext {
        return SplitInteractionContext(
            onDrop: context.onDrop,
            onSplitChild: { childIndex, direction, count, rows, columns in
                var updatedSplit = split
                updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows ?? 2, gridColumns: columns ?? 2)
                context.onUpdateSplit(updatedSplit, "Split Section")
            },
            onUnsplitChild: { childIndex in
                var updatedSplit = split
                updatedSplit.unsplitChild(at: childIndex)
                context.onUpdateSplit(updatedSplit, "Unsplit Section")
            },
            onResize: { childIndex, delta in
                context.onResize(childIndex, delta)
            },
            onUpdateSplit: { updatedChildSplit, actionName in
                var updatedSplit = split
                
                let hasNoRealChildren = updatedChildSplit.children.allSatisfy { $0 == nil }
                let isAlignmentOnly = updatedChildSplit.splitCount == 1 &&
                    hasNoRealChildren &&
                    !updatedChildSplit.childAlignments.isEmpty &&
                    updatedChildSplit.childComponents.isEmpty

                if isAlignmentOnly {
                    let alignment = updatedChildSplit.getAlignment(forChild: 0)
                    let existingComponents = updatedSplit.childComponents[index] ?? []
                    updatedSplit.setAlignment(alignment, forChild: index)
                    updatedSplit.childComponents[index] = existingComponents
                } else {
                    updatedSplit.children[index] = updatedChildSplit
                }
                context.onUpdateSplit(updatedSplit, actionName)
            },
            onAddComponent: { childIdx, component in
                var updatedSplit = split
                if var childSplit = updatedSplit.children[index] {
                    childSplit.addComponent(component, toChild: childIdx)
                    updatedSplit.children[index] = childSplit
                } else {
                    updatedSplit.addComponent(component, toChild: index)
                }
                context.onUpdateSplit(updatedSplit, "Add Component")
            },
            onSetLabel: { childIdx, label in
                var updatedSplit = split
                if let label = label {
                    updatedSplit.setLabel(label, forChild: index)
                } else {
                    updatedSplit.removeLabel(forChild: index)
                }
                context.onUpdateSplit(updatedSplit, "Change Label")
            },
            onReorderChildren: context.onReorderChildren,
            onComponentSelect: context.onComponentSelect,
            onLeafSelect: context.onLeafSelect,
            onSetWidthSizingMode: nil, // Grid cells don't have individual width sizing
            onSetHeightSizingMode: nil, // Grid cells don't have individual height sizing
            onSetGridSizingMode: { childIdx, isRow, mode in
                let (row, column) = split.rowColumn(for: index)
                var updatedSplit = split
                if isRow {
                    updatedSplit.setRowSizingMode(mode, forRow: row)
                } else {
                    updatedSplit.setColumnSizingMode(mode, forColumn: column)
                }
                context.onUpdateSplit(updatedSplit, "Change Grid Sizing")
            },
            currentWidthSizingMode: nil,
            currentHeightSizingMode: nil,
            currentRowSizingMode: split.rowSizingModes.indices.contains(split.rowColumn(for: index).row) ? split.rowSizingModes[split.rowColumn(for: index).row] : nil,
            currentColumnSizingMode: split.columnSizingModes.indices.contains(split.rowColumn(for: index).column) ? split.columnSizingModes[split.rowColumn(for: index).column] : nil,
            showDividers: context.showDividers
        )
    }
}
