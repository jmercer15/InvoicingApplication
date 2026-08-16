import SwiftUI

// MARK: - Layout tokens

enum InspectorLayout {
    static let documentMaxWidth: CGFloat = 1_400
    static let sectionHeaderPadding: CGFloat = 12
    static let sectionHeaderVerticalPadding: CGFloat = 8
    static let sectionContentPadding: CGFloat = 12
    static let fieldSpacing: CGFloat = 12
    static let rowSpacing: CGFloat = 8
    static let compactFieldSpacing: CGFloat = 8
    static let fieldLabelSpacing: CGFloat = 4
    static let iconColumnWidth: CGFloat = 20
    static let editorVerticalPadding: CGFloat = 12
    static let serviceRowPadding: CGFloat = 8
    static let metricGroupHorizontalPadding: CGFloat = 8
    static let metricGroupVerticalPadding: CGFloat = 6
    static let minimumFieldWidth: CGFloat = 96
}

struct InvoiceEditorDocumentPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxWidth: InspectorLayout.documentMaxWidth, alignment: .leading)
    }
}

struct InvoiceEditorSection<Content: View>: View {
    let title: String
    let systemImage: String?
    let contentPadding: CGFloat
    let contentSpacing: CGFloat
    let content: Content

    init(
        title: String,
        systemImage: String? = nil,
        contentPadding: CGFloat = InspectorLayout.sectionContentPadding,
        contentSpacing: CGFloat = InspectorLayout.rowSpacing,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.contentPadding = contentPadding
        self.contentSpacing = contentSpacing
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: InspectorLayout.compactFieldSpacing) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .foregroundStyle(Color.accentColor)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: InspectorLayout.iconColumnWidth)
                }

                Text(title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, InspectorLayout.sectionHeaderPadding)
                .padding(.vertical, InspectorLayout.sectionHeaderVerticalPadding)
                .background(Color.accentColor.opacity(0.13))

            Color.accentColor
                .opacity(0.4)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: contentSpacing) {
                content
            }
            .padding(contentPadding)
            .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay {
            Rectangle()
                .strokeBorder(Color.accentColor.opacity(0.5), lineWidth: 1)
        }
    }
}

struct InvoiceEditorField<Content: View>: View {
    let label: String
    let showsLabel: Bool
    let content: Content

    init(
        label: String,
        showsLabel: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        self.showsLabel = showsLabel
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: InspectorLayout.fieldLabelSpacing) {
            if showsLabel {
                Text(label)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(
            minWidth: InspectorLayout.minimumFieldWidth,
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}

struct InvoiceEditorIconField<Content: View>: View {
    let systemImage: String
    let help: String
    let content: Content

    init(
        systemImage: String,
        help: String,
        @ViewBuilder content: () -> Content
    ) {
        self.systemImage = systemImage
        self.help = help
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: InspectorLayout.compactFieldSpacing) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: InspectorLayout.iconColumnWidth)
                .help(help)
                .accessibilityHidden(true)

            content
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(
            minWidth: InspectorLayout.minimumFieldWidth,
            maxWidth: .infinity,
            alignment: .leading
        )
    }
}

struct InvoiceEditorSummaryRow<Content: View>: View {
    let label: String
    var isEmphasized = false
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: InspectorLayout.fieldSpacing) {
            Text(label)
                .foregroundStyle(isEmphasized ? .primary : .secondary)
                .fontWeight(isEmphasized ? .semibold : .regular)

            Spacer(minLength: InspectorLayout.fieldSpacing)

            content
                .frame(minWidth: InspectorLayout.minimumFieldWidth, alignment: .trailing)
        }
        .frame(maxWidth: .infinity)
    }
}

enum InvoiceInspectorSection: Hashable {
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
