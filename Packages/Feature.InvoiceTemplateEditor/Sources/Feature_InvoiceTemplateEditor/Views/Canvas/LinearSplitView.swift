//
//  LinearSplitView.swift
//  Feature.InvoiceTemplateEditor
//
//  View for rendering linear (horizontal/vertical) splits
//

import SwiftUI
import Core

struct LinearSplitView: View {
    let split: SectionSplit
    let direction: SectionSplit.SplitDirection
    let containerSize: CGSize
    let sectionIndex: Int
    let nodePath: [Int]
    let context: SplitInteractionContext

    var body: some View {
        // Calculate intrinsic sizes for shrink mode
        let intrinsicSizes: [Int: CGFloat] = {
            var sizes: [Int: CGFloat] = [:]
            let axis: SectionSplit.LayoutAxis = direction == .horizontal ? .horizontal : .vertical
            for index in 0..<split.splitCount {
                if let size = split.intrinsicSizeForChild(at: index, along: axis) {
                    sizes[index] = size
                }
            }
            return sizes
        }()
        
        // Use appropriate sizing modes based on split direction
        // Horizontal splits control width, vertical splits control height
        let sizingModes = direction == .horizontal ? split.childWidthSizingModes : split.childHeightSizingModes
        
        return RatioBasedLayout(
            ratios: split.splitRatios,
            sizingModes: sizingModes,
            intrinsicSizes: intrinsicSizes,
            direction: direction,
            containerSize: containerSize,
            spacing: split.childSpacing,
            padding: split.padding,
            onResize: { childIndex, delta in
                var updatedSplit = split
                
                // When manually resized, switch both affected items to fixed mode
                if direction == .horizontal {
                    updatedSplit.setWidthSizingMode(.fixed, forChild: childIndex)
                    if childIndex + 1 < updatedSplit.childWidthSizingModes.count {
                        updatedSplit.setWidthSizingMode(.fixed, forChild: childIndex + 1)
                    }
                } else {
                    updatedSplit.setHeightSizingMode(.fixed, forChild: childIndex)
                    if childIndex + 1 < updatedSplit.childHeightSizingModes.count {
                        updatedSplit.setHeightSizingMode(.fixed, forChild: childIndex + 1)
                    }
                }
                
                switch direction {
                case .horizontal:
                    let width = max(0, containerSize.width - (split.childSpacing * CGFloat(max(0, split.splitCount - 1))) - (split.padding * 2))
                    let (newCurrentRatio, newNextRatio) = safeResizeRatios(
                        delta: delta,
                        containerSize: width,
                        currentRatio: updatedSplit.splitRatios[childIndex],
                        nextRatio: updatedSplit.splitRatios[childIndex + 1]
                    )
                    updatedSplit.updateRatio(at: childIndex, newRatio: newCurrentRatio)
                    updatedSplit.updateRatio(at: childIndex + 1, newRatio: newNextRatio)
                case .vertical:
                    let height = max(0, containerSize.height - (split.childSpacing * CGFloat(max(0, split.splitCount - 1))) - (split.padding * 2))
                    let (newCurrentRatio, newNextRatio) = safeResizeRatios(
                        delta: delta,
                        containerSize: height,
                        currentRatio: updatedSplit.splitRatios[childIndex],
                        nextRatio: updatedSplit.splitRatios[childIndex + 1]
                    )
                    updatedSplit.updateRatio(at: childIndex, newRatio: newCurrentRatio)
                    updatedSplit.updateRatio(at: childIndex + 1, newRatio: newNextRatio)
                default: break
                }
                context.onUpdateSplit(updatedSplit)
            }
        ) { subIndex, calculatedChildSize in
            let childPadding = split.childPaddings.count > subIndex ? split.childPaddings[subIndex] : .zero
            SplittableRectangleView(
                split: split.children[subIndex],
                leafComponents: split.childComponents[subIndex] ?? [],
                containerSize: calculatedChildSize,
                sectionIndex: sectionIndex,
                nodePath: nodePath + [subIndex],
                childIndex: subIndex,
                childPadding: childPadding,
                parentAlignment: split.getAlignment(forChild: subIndex),
                context: makeChildContext(for: subIndex)
            )
        }
    }
    
    private func makeChildContext(for index: Int) -> SplitInteractionContext {
        return SplitInteractionContext(
            onDrop: context.onDrop,
            onSplitChild: { childIndex, direction, count, rows, columns in
                var updatedSplit = split
                updatedSplit.splitChild(at: childIndex, direction: direction, splitCount: count, gridRows: rows ?? 2, gridColumns: columns ?? 2)
                context.onUpdateSplit(updatedSplit)
            },
            onUnsplitChild: { childIndex in
                var updatedSplit = split
                updatedSplit.unsplitChild(at: childIndex)
                context.onUpdateSplit(updatedSplit)
            },
            onResize: { childIndex, delta in
                // This is called when a child (which is a split) resizes ITS children.
                // We don't need to do anything special here, just pass the update up.
                // Wait, the child will call onUpdateSplit with the new child state.
                // So this closure might not be needed if the child handles its own resize logic internally
                // and just calls onUpdateSplit.
                // But SplittableRectangleView calls onResize.
                // If the child is a split, it calls onResize on ITSELF?
                // No, SplittableRectangleView calls onResize when RatioBasedLayout calls it.
                // But that happens inside the child's SplittableRectangleView.
                
                // So this closure is actually for when the CHILD (if it's a split) needs to resize ITS children.
                // But the child will use its OWN context (created by ITS LinearSplitView) to handle that.
                // The `onResize` passed here is only used if the child calls `context.onResize`.
                // `SplittableRectangleView` does NOT call `context.onResize`.
                // It uses `LinearSplitView` which calls `context.onUpdateSplit`.
                
                // So `onResize` here is likely unused by `SplittableRectangleView` unless I missed something.
                // Let's check `SplittableRectangleView`.
                // It passes `context` to `LinearSplitView`.
                // `LinearSplitView` calls `onResize` in `RatioBasedLayout`.
                // That `onResize` is the one defined in `LinearSplitView` (the closure above in `body`).
                // It does NOT call `context.onResize`.
                
                // So `context.onResize` is effectively unused in this architecture!
                // I can leave it empty or just pass a dummy.
                // But for safety/completeness:
                context.onResize(childIndex, delta)
            },
            onUpdateSplit: { updatedChildSplit in
                var updatedSplit = split
                
                // Logic to handle "Alignment Only" splits (merging back to parent if needed)
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
                    // Handle preserving components if replacing a leaf with a split
                    var childSplitToInsert = updatedChildSplit
                    if split.children[index] == nil {
                        let preservedComponents = split.childComponents[index] ?? []
                        if !preservedComponents.isEmpty,
                           childSplitToInsert.children.count > 0,
                           childSplitToInsert.children[0] == nil {
                            childSplitToInsert.childComponents[0] = preservedComponents
                        }
                    }
                    updatedSplit.children[index] = childSplitToInsert
                    if updatedSplit.children[index] != nil {
                        updatedSplit.childComponents.removeValue(forKey: index)
                    }
                }
                context.onUpdateSplit(updatedSplit)
            },
            onAddComponent: { childIdx, component in
                var updatedSplit = split
                if var childSplit = updatedSplit.children[index] {
                    childSplit.addComponent(component, toChild: childIdx)
                    updatedSplit.children[index] = childSplit
                } else {
                    updatedSplit.addComponent(component, toChild: index)
                }
                context.onUpdateSplit(updatedSplit)
            },
            onSetLabel: { childIdx, label in
                // If the child is a leaf, childIdx should be `index` (relative to this split).
                // But wait, `LeafContentView` calls `onSetLabel(childIndex, label)`.
                // `childIndex` there is `subIndex` passed from here.
                // So `childIdx` == `index`.
                var updatedSplit = split
                if let label = label {
                    updatedSplit.setLabel(label, forChild: index)
                } else {
                    updatedSplit.removeLabel(forChild: index)
                }
                context.onUpdateSplit(updatedSplit)
            },
            onReorderChildren: context.onReorderChildren,
            onComponentSelect: context.onComponentSelect,
            onLeafSelect: context.onLeafSelect,
            onSetWidthSizingMode: direction == .horizontal ? { childIdx, mode in
                // Horizontal splits control width
                var updatedSplit = split
                updatedSplit.setWidthSizingMode(mode, forChild: index)
                context.onUpdateSplit(updatedSplit)
            } : nil,
            onSetHeightSizingMode: direction == .vertical ? { childIdx, mode in
                // Vertical splits control height
                var updatedSplit = split
                updatedSplit.setHeightSizingMode(mode, forChild: index)
                context.onUpdateSplit(updatedSplit)
            } : nil,
            onSetGridSizingMode: nil // Linear splits don't use grid sizing
        )
    }
}
