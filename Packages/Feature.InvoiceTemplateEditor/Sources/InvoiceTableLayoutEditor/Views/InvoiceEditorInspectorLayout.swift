import SwiftUI

// MARK: - Layout tokens

enum InspectorLayout {
    static let scrollHorizontalPadding: CGFloat = 12
}

enum InvoiceInspectorSection: String, CaseIterable, Identifiable {
    case header
    case from
    case billedTo
    case recipient
    case lineItems
    case totals
    case paymentDetails
    case paymentTerms
    case validation
    case settings

    var id: Self {
        self
    }

    var displayName: String {
        switch self {
        case .header: "Header"
        case .from: "From"
        case .billedTo: "Billed To"
        case .recipient: "For"
        case .lineItems: "Line Items"
        case .totals: "Totals"
        case .paymentDetails: "Payment Details"
        case .paymentTerms: "Payment Terms"
        case .validation: "Validation"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .header: "doc.text"
        case .from: "building.2"
        case .billedTo: "person.text.rectangle"
        case .recipient: "person"
        case .lineItems: "list.bullet.rectangle"
        case .totals: "sum"
        case .paymentDetails: "building.columns"
        case .paymentTerms: "doc.plaintext"
        case .validation: "exclamationmark.triangle"
        case .settings: "gearshape"
        }
    }
}

/// Bridges discrete line-item edits to the standard macOS Edit > Undo / Redo commands.
@MainActor
final class InvoiceLineItemUndoCoordinator {
    private(set) var activeDocumentID: UUID?

    /// UndoManager belongs to the window, while invoice drafts change in place.
    /// Remove only this coordinator's actions when document identity changes so
    /// an old line-item action can never mutate the newly selected invoice.
    func activateDocument(id: UUID?, undoManager: UndoManager?) {
        guard activeDocumentID != id else { return }
        undoManager?.removeAllActions(withTarget: self)
        activeDocumentID = id
    }

    func addLineItem(
        to viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) -> UUID {
        let documentID = viewModel.selectedInvoiceID
        activateDocument(id: documentID, undoManager: undoManager)
        let itemID = viewModel.addLineItem()
        registerUndoForAddition(
            itemID: itemID,
            documentID: documentID,
            viewModel: viewModel,
            undoManager: undoManager
        )
        undoManager?.setActionName("Add Line Item")
        return itemID
    }

    func removeLineItem(
        id: UUID,
        from viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) {
        let documentID = viewModel.selectedInvoiceID
        activateDocument(id: documentID, undoManager: undoManager)
        guard let removal = viewModel.removeLineItemForUndo(id: id) else { return }
        registerUndoForRemoval(
            removal,
            documentID: documentID,
            viewModel: viewModel,
            undoManager: undoManager
        )
        undoManager?.setActionName("Remove Line Item")
        viewModel.statusMessage = "Line item removed. Use Edit > Undo to restore it."
    }

    func registerUndoForAddition(
        itemID: UUID,
        documentID: UUID?,
        viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) {
        undoManager?.registerUndo(withTarget: self) { coordinator in
            guard coordinator.owns(documentID, in: viewModel) else { return }
            guard let removal = viewModel.removeLineItemForUndo(id: itemID) else { return }
            coordinator.registerUndoForRemoval(
                removal,
                documentID: documentID,
                viewModel: viewModel,
                undoManager: undoManager
            )
            undoManager?.setActionName("Add Line Item")
        }
    }

    func registerUndoForRemoval(
        _ removal: InvoiceLineItemRemoval,
        documentID: UUID?,
        viewModel: InvoiceEditorViewModel,
        undoManager: UndoManager?
    ) {
        undoManager?.registerUndo(withTarget: self) { coordinator in
            guard coordinator.owns(documentID, in: viewModel) else { return }
            viewModel.restoreLineItem(removal)
            coordinator.registerUndoForAddition(
                itemID: removal.item.id,
                documentID: documentID,
                viewModel: viewModel,
                undoManager: undoManager
            )
            undoManager?.setActionName("Remove Line Item")
        }
    }

    func owns(_ documentID: UUID?, in viewModel: InvoiceEditorViewModel) -> Bool {
        activeDocumentID == documentID && viewModel.selectedInvoiceID == documentID
    }
}

/// Makes the full inspector section label a native button target, rather than limiting
/// expansion to the disclosure chevron's hit area.
struct InspectorDisclosureGroupStyle: DisclosureGroupStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) {
                    configuration.isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: configuration.isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    configuration.label
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint("Shows or hides this section's fields")

            if configuration.isExpanded {
                configuration.content
            }
        }
    }
}
