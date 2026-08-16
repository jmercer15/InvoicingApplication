import Observation
import SwiftUI

enum InvoiceInspectorFocusTarget: Hashable {
    // Legacy section targets remain while document renderers migrate to the
    // field-level targets below.
    case header
    case invoiceNumber
    case issueDate
    case dueDate
    case from
    case billedTo
    case recipient
    case lineItems
    case lineItem(UUID)
    case totals
    case paymentDetails
    case paymentTerms
    case notes

    case sellerName, sellerAddress, sellerEmail, sellerPhone, sellerTaxID
    case billParticipantDirectly
    case billToName, billToAddress, billToEmail, billToPhone, billingAuthority
    case clientName, clientAddress, clientEmail, clientPhone, clientTaxID
    case lineItemServiceDate(UUID)
    case lineItemDescription(UUID)
    case lineItemCode(UUID)
    case lineItemQuantity(UUID)
    case lineItemUnit(UUID)
    case lineItemUnitPrice(UUID)
    case lineItemTaxRate(UUID)
    case discountPercent, discountAmount, creditApplied
    case bankName, bankAccountName, bankBSB, bankAccountNumber
    case currencyCode, defaultTaxRate
}

@Observable
@MainActor
final class InvoicePreviewInspectorInteraction {
    enum Mode: Equatable {
        case invoiceData
        case templateFormatting
        case disabled
    }

    struct FocusRequest: Equatable {
        let id = UUID()
        let target: InvoiceInspectorFocusTarget
    }

    let mode: Mode
    private(set) var focusRequest: FocusRequest?
    private(set) var formatInspectorRevealRevision = 0
    private(set) var requestedFormatSection: InvoiceTemplateFormatSection?

    var allowsFieldTargeting: Bool { mode == .invoiceData }
    var allowsFormatInspectorReveal: Bool { mode == .templateFormatting }
    var allowsPreviewTargetSelection: Bool { mode != .disabled }

    init(isEnabled: Bool = true) {
        mode = isEnabled ? .invoiceData : .disabled
    }

    init(mode: Mode) {
        self.mode = mode
    }

    func select(_ target: InvoiceInspectorFocusTarget) {
        switch mode {
        case .invoiceData:
            focusRequest = FocusRequest(target: target)
        case .templateFormatting:
            requestedFormatSection = InvoiceTemplateFormatSection.destination(for: target)
            revealFormatInspector()
        case .disabled:
            return
        }
    }

    func revealFormatInspector() {
        guard allowsFormatInspectorReveal else { return }
        formatInspectorRevealRevision &+= 1
    }

    func completeFocusRequest(id: UUID) {
        guard focusRequest?.id == id else { return }
        focusRequest = nil
    }

    func accessibilityLabel(for target: InvoiceInspectorFocusTarget) -> String {
        switch mode {
        case .invoiceData:
            "Edit \(target.previewInteractionLabel)"
        case .templateFormatting:
            "Format \(target.previewInteractionLabel)"
        case .disabled:
            target.previewInteractionLabel
        }
    }

    func accessibilityHint(for target: InvoiceInspectorFocusTarget) -> String {
        switch mode {
        case .invoiceData:
            return "Opens related invoice data controls in the editor"
        case .templateFormatting:
            let section = InvoiceTemplateFormatSection.destination(for: target)
            return "Opens \(section.title) format section without changing mock invoice data"
        case .disabled:
            return ""
        }
    }

    func helpText(for target: InvoiceInspectorFocusTarget) -> String {
        switch mode {
        case .invoiceData:
            return "Edit \(target.previewInteractionLabel) in the invoice editor"
        case .templateFormatting:
            let section = InvoiceTemplateFormatSection.destination(for: target)
            return "Format \(target.previewInteractionLabel) in \(section.title)"
        case .disabled:
            return target.previewInteractionLabel
        }
    }
}

struct InvoiceInspectorDeferredFocusLease: Equatable {
    let id: UUID
    let documentID: UUID?

    init(id: UUID = UUID(), documentID: UUID?) {
        self.id = id
        self.documentID = documentID
    }

    func isCurrent(activeLeaseID: UUID?, selectedDocumentID: UUID?) -> Bool {
        activeLeaseID == id && selectedDocumentID == documentID
    }
}

enum InvoiceEditorInspectorMode: Equatable, Sendable {
    case invoiceData
    case templateFormatting
}

/// Inspector sidebar with all editable invoice fields.
///
/// Layout mirrors the invoice document top-to-bottom:
/// Header → Parties → Line Items (+ Totals) → Payment → editor-only.
/// Uses a native `Form` so macOS owns field spacing, keyboard traversal, and scrolling.
/// The line-items section still chooses its table or compact-card presentation from its
