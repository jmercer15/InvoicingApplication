//
//  LeafContentView.swift
//  Feature.InvoiceTemplateEditor
//
//  View for rendering leaf content in the split system
//

import SwiftUI
import Core

struct LeafContentView: View {
    let components: [InvoiceComponent]
    let containerSize: CGSize
    let sectionIndex: Int
    let childIndex: Int
    let nodePath: [Int]
    let parentAlignment: SectionSplit.LeafAlignment
    let onAddComponent: (InvoiceComponent) -> Void
    let onSplit: (SectionSplit.SplitDirection, Int, Int?, Int?) -> Void
    let onUnsplit: (() -> Void)?
    let onSetLabel: ((String?) -> Void)?
    let onSetAlignment: ((SectionSplit.LeafAlignment) -> Void)?
    let onSetWidthSizingMode: ((SectionSplit.SizingMode) -> Void)?
    let onSetHeightSizingMode: ((SectionSplit.SizingMode) -> Void)?
    let onSetGridSizingMode: ((Bool, SectionSplit.SizingMode) -> Void)?
    let onComponentSelect: (InvoiceComponent) -> Void
    let onLeafSelect: ((SectionSplitSelection) -> Void)?
    
    var body: some View {
        let selectionPath = nodePath.isEmpty ? [0] : nodePath
        
        ContentRectangleView(
            components: components,
            containerSize: containerSize,
            sectionLabel: nil,
            contentAlignment: parentAlignment,
            sectionIndex: sectionIndex,
            childIndex: childIndex,
            leafPath: selectionPath,
            onAddComponent: onAddComponent,
            onSplit: onSplit,
            onUnsplit: onUnsplit,
            onSetLabel: onSetLabel,
            onSetAlignment: onSetAlignment,
            onSetWidthSizingMode: onSetWidthSizingMode,
            onSetHeightSizingMode: onSetHeightSizingMode,
            onSetGridSizingMode: onSetGridSizingMode,
            onComponentSelect: onComponentSelect,
            onLeafSelect: { _ in
                onLeafSelect?(SectionSplitSelection(sectionIndex: sectionIndex, path: selectionPath))
            },
            allowDrop: components.isEmpty
        )
    }
}
