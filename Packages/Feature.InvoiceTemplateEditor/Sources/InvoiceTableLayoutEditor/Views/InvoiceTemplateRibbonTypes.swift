import AppKit
import SwiftUI

enum InvoiceTemplateFormatSection: String, CaseIterable, Identifiable {
  case template
  case layout
  case design
  case content
  case lineItems

  var id: Self { self }

  var title: String {
    switch self {
    case .template: "Template"
    case .layout: "Layout"
    case .design: "Design"
    case .content: "Content"
    case .lineItems: "Table"
    }
  }

  var systemImage: String {
    switch self {
    case .template: "square.grid.2x2"
    case .layout: "doc"
    case .design: "paintpalette"
    case .content: "text.page"
    case .lineItems: "tablecells"
    }
  }

  static func destination(for target: InvoiceInspectorFocusTarget) -> Self {
    switch target {
    case .header, .from, .billedTo, .recipient:
      .template
    case .lineItems, .lineItem, .totals,
         .lineItemServiceDate, .lineItemDescription, .lineItemCode,
         .lineItemQuantity, .lineItemUnit, .lineItemUnitPrice, .lineItemTaxRate,
         .discountPercent, .discountAmount, .creditApplied,
         .currencyCode, .defaultTaxRate:
      .lineItems
    case .invoiceNumber, .issueDate, .dueDate,
         .paymentDetails, .paymentTerms, .notes,
         .sellerName, .sellerAddress, .sellerEmail, .sellerPhone, .sellerTaxID,
         .billParticipantDirectly,
         .billToName, .billToAddress, .billToEmail, .billToPhone, .billingAuthority,
         .clientName, .clientAddress, .clientEmail, .clientPhone, .clientTaxID,
         .bankName, .bankAccountName, .bankBSB, .bankAccountNumber:
      .content
    }
  }
}

enum InvoiceTemplateGeometryInputID {
  static let pageWidth = "template.page.width"
  static let pageHeight = "template.page.height"
  static let margin = "template.page.margin"
  static let typographyScale = "template.typographyScale"
  static let spacingScale = "template.spacingScale"
  static let borderWidth = "template.borderWidth"
}

enum InvoiceTemplateInvalidInputDestination {
  static func section(for inputID: String) -> InvoiceTemplateFormatSection? {
    switch inputID {
    case InvoiceTemplateGeometryInputID.pageWidth,
         InvoiceTemplateGeometryInputID.pageHeight,
         InvoiceTemplateGeometryInputID.margin:
      .layout
    case InvoiceTemplateGeometryInputID.typographyScale,
         InvoiceTemplateGeometryInputID.spacingScale,
         InvoiceTemplateGeometryInputID.borderWidth:
      .design
    default:
      nil
    }
  }

  /// Stable section priority avoids Set iteration order changing recovery destination.
  static func firstSection(for inputIDs: Set<String>) -> InvoiceTemplateFormatSection? {
    let destinations = Set(inputIDs.compactMap(section(for:)))
    return InvoiceTemplateFormatSection.allCases.first(where: destinations.contains)
  }
}

enum InvoiceTemplateInputRelevance {
  static func disabledInputIDs(tableStyle: InvoiceTableStyle) -> Set<String> {
    tableStyle == .borderless
      ? [InvoiceTemplateGeometryInputID.borderWidth]
      : []
  }
}

@MainActor
enum InvoiceTemplateNumericDraftResolution {
  /// Alternate controls replace exact text, so apply typed value first and then force field state
  /// to adopt that new baseline. Reversing this order can restore stale text while field is focused.
  static func replace(
    inputID: String,
    toolbarState: InvoiceEditorToolbarState,
    onValidityChange: (String, Bool) -> Void,
    applying mutation: () -> Void
  ) {
    mutation()
    toolbarState.resetNumericInputDraft(inputID)
    onValidityChange(inputID, false)
  }
}

/// Presentation and command controls displayed in the inspector's Format tab.
