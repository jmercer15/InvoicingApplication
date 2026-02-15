//
//  SplitInteractionContext.swift
//  Feature.InvoiceTemplateEditor
//
//  Context struct to hold callback closures for split interactions
//

import SwiftUI
import Core

struct SplitInteractionContext {
    let onDrop: (NSItemProvider, CGPoint) -> Bool
    let onSplitChild: (Int, SectionSplit.SplitDirection, Int, Int?, Int?) -> Void
    let onUnsplitChild: (Int) -> Void
    let onResize: (Int, CGFloat) -> Void
    var onResizeStart: ((Int) -> Void)? = nil
    let onUpdateSplit: (SectionSplit, String?) -> Void
    let onAddComponent: (Int, InvoiceComponent) -> Void
    let onSetLabel: ((Int, String?) -> Void)?
    let onReorderChildren: ((Int, Int) -> Void)?
    let onComponentSelect: (InvoiceComponent) -> Void
    let onLeafSelect: ((SectionSplitSelection) -> Void)?
    let onSetWidthSizingMode: ((Int, SectionSplit.SizingMode) -> Void)?
    let onSetHeightSizingMode: ((Int, SectionSplit.SizingMode) -> Void)?
    let onSetGridSizingMode: ((Int, Bool, SectionSplit.SizingMode) -> Void)? // index, isRow, mode
    let currentWidthSizingMode: SectionSplit.SizingMode?
    let currentHeightSizingMode: SectionSplit.SizingMode?
    let currentRowSizingMode: SectionSplit.SizingMode?
    let currentColumnSizingMode: SectionSplit.SizingMode?
    let showDividers: Bool
}
