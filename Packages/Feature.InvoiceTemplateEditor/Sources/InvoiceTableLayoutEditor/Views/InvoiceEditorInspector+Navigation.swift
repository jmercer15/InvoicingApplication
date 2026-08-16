import Core
import SwiftUI

extension InvoiceEditorInspector {
    func focus(
        _ request: InvoicePreviewInspectorInteraction.FocusRequest,
        proxy: ScrollViewProxy
    ) {
        let target = request.target
        let resolvedFocusTarget: InvoiceInspectorFocusTarget =
            target == .billParticipantDirectly ? .billingAuthority : target
        let section: InvoiceInspectorSection
        switch target {
        case .header, .invoiceNumber, .issueDate, .dueDate:
            section = .header
        case .from, .sellerName, .sellerAddress, .sellerEmail, .sellerPhone, .sellerTaxID:
            section = .from
        case .billedTo, .billParticipantDirectly, .billToName, .billToAddress, .billToEmail,
             .billToPhone, .billingAuthority:
            section = .billedTo
        case .recipient, .clientName, .clientAddress, .clientEmail, .clientPhone, .clientTaxID:
            section = .recipient
        case .lineItems, .lineItem, .lineItemServiceDate, .lineItemDescription, .lineItemCode,
             .lineItemQuantity, .lineItemUnit, .lineItemUnitPrice, .lineItemTaxRate:
            section = .lineItems
        case .totals, .discountPercent, .discountAmount, .creditApplied:
            section = .totals
        case .paymentDetails, .bankName, .bankAccountName, .bankBSB, .bankAccountNumber:
            section = .paymentDetails
        case .paymentTerms, .notes:
            section = .paymentTerms
        case .currencyCode, .defaultTaxRate:
            section = .settings
        }
        let lease = InvoiceInspectorDeferredFocusLease(
            id: request.id,
            documentID: viewModel.selectedInvoiceID
        )
        activeDeferredFocusLeaseID = lease.id
        if section != .settings {
            withAnimation(motionAnimation) { proxy.scrollTo(section, anchor: .top) }
        }
        Task { @MainActor in
            await Task.yield()
            previewInteraction.completeFocusRequest(id: request.id)
            guard lease.isCurrent(
                activeLeaseID: activeDeferredFocusLeaseID,
                selectedDocumentID: viewModel.selectedInvoiceID
            ) else { return }
            if let itemID = lineItemID(for: target) {
                withAnimation(motionAnimation) { proxy.scrollTo(itemID, anchor: .center) }
            }
            focusedTarget = resolvedFocusTarget
        }
    }

    func lineItemID(for target: InvoiceInspectorFocusTarget) -> UUID? {
        switch target {
        case let .lineItem(itemID), let .lineItemServiceDate(itemID),
             let .lineItemDescription(itemID), let .lineItemCode(itemID),
             let .lineItemQuantity(itemID), let .lineItemUnit(itemID),
             let .lineItemUnitPrice(itemID), let .lineItemTaxRate(itemID):
            itemID
        default:
            nil
        }
    }

    func addLineItemFromCommand() {
        let itemID = addLineItem()
        let lease = InvoiceInspectorDeferredFocusLease(
            documentID: viewModel.selectedInvoiceID
        )
        activeDeferredFocusLeaseID = lease.id
        // The Invoice tab is created after this command changes the selected tab.
        // Yield once so SwiftUI can install the field before assigning focus.
        Task { @MainActor [itemID, lease] in
            await Task.yield()
            guard lease.isCurrent(
                activeLeaseID: activeDeferredFocusLeaseID,
                selectedDocumentID: viewModel.selectedInvoiceID
            ) else { return }
            focusedTarget = .lineItemDescription(itemID)
        }
    }

    func handleAddLineItemRequest() {
        let revision = toolbarState.addLineItemRequestRevision
        guard revision > 0,
              revision != handledAddLineItemRequestRevision,
              !viewModel.isBusy
        else { return }
        handledAddLineItemRequestRevision = revision
        addLineItemFromCommand()
    }

    @discardableResult
    func addLineItem() -> UUID {
        lineItemUndo.addLineItem(
            to: viewModel,
            undoManager: undoManager
        )
    }
}
