import Observation
import SwiftUI

/// App-command bridge for the active table-layout invoice editor.
///
/// Keeping this as one focused value lets the app shell route menu commands to
/// the editor without owning editor state or reaching through feature views.
@Observable
@MainActor
public final class InvoiceEditorCommandActions {
    public var isInvoiceContext = false
    public var canCreate = false
    public var canSave = false
    public var canDuplicate = false
    public var canAddLineItem = false
    public var canDelete = false
    public var canPrint = false
    public var canExportPDF = false
    public var canToggleInspector = false
    public var canZoomIn = false
    public var canZoomOut = false
    public var canSetActualSize = false
    public var canFitWidth = false
    /// Flushes focused-editor state needed by Feature.Invoices before it creates a record.
    /// Returns false when creation must stop (for example, unsaved or invalid template defaults).
    public var prepareForInvoiceCreation: @MainActor () async -> Bool = { true }
    public var save: () -> Void = {}
    public var duplicate: () -> Void = {}
    public var addLineItem: () -> Void = {}
    public var requestDelete: () -> Void = {}
    public var print: () -> Void = {}
    public var exportPDF: () -> Void = {}
    public var toggleInspector: () -> Void = {}
    public var zoomIn: () -> Void = {}
    public var zoomOut: () -> Void = {}
    public var setActualSize: () -> Void = {}
    public var fitWidth: () -> Void = {}

    public init() {}

    public init(
        canCreate: Bool,
        canSave: Bool,
        canDuplicate: Bool,
        canDelete: Bool,
        canPrint: Bool,
        canExportPDF: Bool,
        canToggleInspector: Bool = false,
        prepareForInvoiceCreation: @escaping @MainActor () async -> Bool = { true },
        save: @escaping () -> Void,
        duplicate: @escaping () -> Void,
        requestDelete: @escaping () -> Void,
        print: @escaping () -> Void,
        exportPDF: @escaping () -> Void,
        toggleInspector: @escaping () -> Void = {},
        canAddLineItem: Bool = false,
        addLineItem: @escaping () -> Void = {},
        canZoomIn: Bool = false,
        canZoomOut: Bool = false,
        canSetActualSize: Bool = false,
        canFitWidth: Bool = false,
        zoomIn: @escaping () -> Void = {},
        zoomOut: @escaping () -> Void = {},
        setActualSize: @escaping () -> Void = {},
        fitWidth: @escaping () -> Void = {}
    ) {
        self.canCreate = canCreate
        self.canSave = canSave
        self.canDuplicate = canDuplicate
        self.canDelete = canDelete
        self.canPrint = canPrint
        self.canExportPDF = canExportPDF
        self.canToggleInspector = canToggleInspector
        self.prepareForInvoiceCreation = prepareForInvoiceCreation
        self.save = save
        self.duplicate = duplicate
        self.canAddLineItem = canAddLineItem
        self.addLineItem = addLineItem
        self.requestDelete = requestDelete
        self.print = print
        self.exportPDF = exportPDF
        self.toggleInspector = toggleInspector
        self.canZoomIn = canZoomIn
        self.canZoomOut = canZoomOut
        self.canSetActualSize = canSetActualSize
        self.canFitWidth = canFitWidth
        self.zoomIn = zoomIn
        self.zoomOut = zoomOut
        self.setActualSize = setActualSize
        self.fitWidth = fitWidth
    }

    public func updateCapabilities(
        canCreate: Bool,
        canSave: Bool,
        canDuplicate: Bool,
        canDelete: Bool,
        canPrint: Bool,
        canExportPDF: Bool,
        canToggleInspector: Bool,
        isInvoiceContext: Bool,
        canAddLineItem: Bool = false,
        canZoomIn: Bool = false,
        canZoomOut: Bool = false,
        canSetActualSize: Bool = false,
        canFitWidth: Bool = false
    ) {
        if self.canCreate != canCreate { self.canCreate = canCreate }
        if self.canSave != canSave { self.canSave = canSave }
        if self.canDuplicate != canDuplicate { self.canDuplicate = canDuplicate }
        if self.canDelete != canDelete { self.canDelete = canDelete }
        if self.canPrint != canPrint { self.canPrint = canPrint }
        if self.canExportPDF != canExportPDF { self.canExportPDF = canExportPDF }
        if self.canToggleInspector != canToggleInspector {
            self.canToggleInspector = canToggleInspector
        }
        if self.canAddLineItem != canAddLineItem { self.canAddLineItem = canAddLineItem }
        if self.canZoomIn != canZoomIn { self.canZoomIn = canZoomIn }
        if self.canZoomOut != canZoomOut { self.canZoomOut = canZoomOut }
        if self.canSetActualSize != canSetActualSize {
            self.canSetActualSize = canSetActualSize
        }
        if self.canFitWidth != canFitWidth { self.canFitWidth = canFitWidth }
        if self.isInvoiceContext != isInvoiceContext {
            self.isInvoiceContext = isInvoiceContext
        }
    }
}

private struct InvoiceEditorCommandActionsKey: FocusedValueKey {
    typealias Value = InvoiceEditorCommandActions
}

public extension FocusedValues {
    var invoiceEditorCommandActions: InvoiceEditorCommandActions? {
        get { self[InvoiceEditorCommandActionsKey.self] }
        set { self[InvoiceEditorCommandActionsKey.self] = newValue }
    }
}
