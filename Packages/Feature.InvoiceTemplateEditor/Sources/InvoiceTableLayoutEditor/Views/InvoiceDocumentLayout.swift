import SwiftUI

enum InvoiceDocumentLayout {
  static let sectionSpacing: CGFloat = 12
  static let lineItemsTitleSpacing: CGFloat = 7
  static let compactRowSpacing: CGFloat = 3
  static let compactBlockSpacing: CGFloat = 7
  /// Top padding above the line items table after the document header/parties block.
  static let lineItemsTopPadding: CGFloat = 12
  static let footerSpacing: CGFloat = 7
  static let footerRowSpacing: CGFloat = 3
  static let partyBlockTitleSpacing: CGFloat = 4
  /// Horizontal gap between party columns (From | Billed To | For) on wide layouts.
  static let partyColumnSpacing: CGFloat = 14
  static func sectionSpacing(scale: CGFloat) -> CGFloat {
    (sectionSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func lineItemsTitleSpacing(scale: CGFloat) -> CGFloat {
    (lineItemsTitleSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func compactBlockSpacing(scale: CGFloat) -> CGFloat {
    (compactBlockSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func lineItemsTopPadding(scale: CGFloat) -> CGFloat {
    (lineItemsTopPadding * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func footerSpacing(scale: CGFloat) -> CGFloat {
    (footerSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

  static func partyColumnSpacing(scale: CGFloat) -> CGFloat {
    (partyColumnSpacing * scale).rounded(.toNearestOrAwayFromZero)
  }

}

/// Which provider/participant fields appear on an NDIS-compliant invoice document.
enum PartyPreviewProfile {
  /// Provider: business name, address, contact details, ABN.
  case provider
  /// Participant: name and NDIS number only.
  case participant
  /// Invoice recipient when plan-managed (name and email).
  case billingContact
}
