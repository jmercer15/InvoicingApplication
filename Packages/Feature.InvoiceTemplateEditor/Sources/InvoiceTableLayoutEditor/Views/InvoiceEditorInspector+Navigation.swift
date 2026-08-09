import Core
import SwiftUI

extension InvoiceEditorInspector {
    func navigate(to section: InvoiceInspectorSection, proxy: ScrollViewProxy) {
        activeDeferredFocusLeaseID = nil
        withAnimation(subtleAnimation) {
            expand(section)
            proxy.scrollTo(section, anchor: .top)
        }
    }

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
        expandedSection = section
        if let itemID = lineItemID(for: target) {
            expandedLineItemID = itemID
        }
        let lease = InvoiceInspectorDeferredFocusLease(
            id: request.id,
            documentID: viewModel.selectedInvoiceID
        )
        activeDeferredFocusLeaseID = lease.id
        withAnimation(motionAnimation) { proxy.scrollTo(section, anchor: .top) }
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

    func expand(_ section: InvoiceInspectorSection) {
        guard section != .validation else { return }
        expandedSection = section
    }

    func collapseAllSections() {
        activeDeferredFocusLeaseID = nil
        expandedSection = nil
        expandedLineItemID = nil
        focusedTarget = nil
    }

    func isExpanded(_ section: InvoiceInspectorSection) -> Bool {
        expandedSection == section
    }

    func expansionBinding(for section: InvoiceInspectorSection) -> Binding<Bool> {
        Binding(
            get: { isExpanded(section) },
            set: { isNowExpanded in
                activeDeferredFocusLeaseID = nil
                withAnimation(motionAnimation) {
                    expandedSection = isNowExpanded ? section : nil
                }
            }
        )
    }

    func lineItemExpansionBinding(for itemID: UUID) -> Binding<Bool> {
        Binding(
            get: { expandedLineItemID == itemID },
            set: { isNowExpanded in
                activeDeferredFocusLeaseID = nil
                withAnimation(motionAnimation) {
                    expandedLineItemID = isNowExpanded ? itemID : nil
                }
            }
        )
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
        expandedSection = .lineItems
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
        let itemID = lineItemUndo.addLineItem(
            to: viewModel,
            undoManager: undoManager
        )
        expandedLineItemID = itemID
        return itemID
    }
}
