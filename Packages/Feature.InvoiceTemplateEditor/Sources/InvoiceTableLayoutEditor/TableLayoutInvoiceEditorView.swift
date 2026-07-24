import SwiftUI

/// Public host with two intentionally separate entry points:
/// template workspace uses mock content; invoice workspace uses persisted application invoices.
public struct TableLayoutInvoiceEditorView: View {
    private enum Workspace {
        case template(
            onCreateInvoice: (@MainActor () async throws -> Void)?,
            onOpenInvoices: (@MainActor () -> Void)?,
            isCreatingInvoice: Bool
        )
        case invoice(
            selection: Binding<UUID?>,
            session: InvoiceEditorSession,
            onCreateInvoice: (@MainActor () async throws -> Void)?,
            onOpenTemplateEditor: (@MainActor () -> Void)?,
            isCreatingInvoice: Bool
        )
    }

    private let workspace: Workspace

    /// Template workspace: mock document, format inspector, no invoice list or data editor.
    public init(
        onCreateInvoice: (@MainActor () async throws -> Void)? = nil,
        onOpenInvoices: (@MainActor () -> Void)? = nil,
        isCreatingInvoice: Bool = false
    ) {
        workspace = .template(
            onCreateInvoice: onCreateInvoice,
            onOpenInvoices: onOpenInvoices,
            isCreatingInvoice: isCreatingInvoice
        )
    }

    /// Invoice workspace: persisted document, data inspector, list owned by Feature.Invoices.
    public init(
        selection: Binding<UUID?>,
        session: InvoiceEditorSession,
        onCreateInvoice: (@MainActor () async throws -> Void)? = nil,
        onOpenTemplateEditor: (@MainActor () -> Void)? = nil,
        isCreatingInvoice: Bool = false
    ) {
        workspace = .invoice(
            selection: selection,
            session: session,
            onCreateInvoice: onCreateInvoice,
            onOpenTemplateEditor: onOpenTemplateEditor,
            isCreatingInvoice: isCreatingInvoice
        )
    }

    @ViewBuilder
    public var body: some View {
        switch workspace {
        case .template(let onCreateInvoice, let onOpenInvoices, let isCreatingInvoice):
            InvoiceRootView(
                onCreateInvoice: onCreateInvoice,
                onOpenInvoices: onOpenInvoices,
                featureInvoiceCreationIsActive: isCreatingInvoice
            )
        case .invoice(
            let selection,
            let session,
            let onCreateInvoice,
            let onOpenTemplateEditor,
            let isCreatingInvoice
        ):
            InvoiceRootView(
                viewModel: session.viewModel,
                externalSelection: selection,
                numericInputDrafts: session.numericInputDrafts,
                onCreateInvoice: onCreateInvoice,
                onOpenTemplateEditor: onOpenTemplateEditor,
                featureInvoiceCreationIsActive: isCreatingInvoice
            )
        }
    }
}
