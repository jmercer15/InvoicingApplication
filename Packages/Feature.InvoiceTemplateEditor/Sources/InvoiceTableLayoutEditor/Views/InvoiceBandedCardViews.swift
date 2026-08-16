import SharedUI
import SwiftUI

// MARK: - Banded Card Views

struct DocumentBandedCardStyle {
  var bandFill: Color
  var bodyFill: Color
  var outline: Color
  var bandRule: Color

  /// Soft, airy card for the From / Billed To / For party blocks.
  static let party = DocumentBandedCardStyle(
    bandFill: InvoiceDocumentDesign.partyBandFill,
    bodyFill: InvoiceDocumentDesign.partyBodyFill,
    outline: InvoiceDocumentDesign.partyCardOutline,
    bandRule: InvoiceDocumentDesign.partyBandRule
  )

  static func party(theme: InvoiceThemePalette) -> DocumentBandedCardStyle {
    DocumentBandedCardStyle(
      bandFill: theme.partyBandFill,
      bodyFill: InvoiceDocumentDesign.partyBodyFill,
      outline: theme.partyCardOutline,
      bandRule: theme.partyBandRule
    )
  }

  static func payment(theme: InvoiceThemePalette) -> DocumentBandedCardStyle {
    DocumentBandedCardStyle(
      bandFill: theme.paymentBandFill,
      bodyFill: InvoiceDocumentDesign.paymentBodyFill,
      outline: theme.paymentCardOutline,
      bandRule: theme.paymentBandRule
    )
  }
}

/// A framed card with a tinted accent header band carrying a small-caps section
/// label, sitting above a padded body. A lighter, tabular echo of the header
/// banner used for the party blocks and the payment footer so those sections
/// feel as intentional as the header + invoice-details table.
struct DocumentBandedCard<Content: View>: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle

  let label: String
  var style: DocumentBandedCardStyle = .party
  /// Trailing accessory rendered in the header band (e.g. a short subtitle).
  var accessory: String? = nil
  /// When true the body has no inset so ruled rows can span edge to edge.
  var flushBody: Bool = false
  /// Whether the accent label band is rendered above the card body.
  var showsHeaderBand: Bool = true
  /// Whether the card's outer stroke and header-band rule are rendered.
  var showsOutline: Bool = true
  /// When true the card stretches to the height proposed by its parent (e.g. an
  /// equal-height party row) while keeping content top-aligned.
  var expandsToFillHeight: Bool = false
  /// When true the card stretches to the width proposed by its parent. Set
  /// false for side-by-side party cards so each column hugs its content.
  var expandsToFillWidth: Bool = true
  /// Optional field target for the header band. The body remains free to
  /// expose smaller, independent targets without gesture competition.
  var inspectorHeaderTarget: InvoiceInspectorFocusTarget?
  var inspectorInteraction: InvoicePreviewInspectorInteraction?
  @ViewBuilder var content: () -> Content

  var body: some View {
    let shape = Rectangle()
    let strokeWidth = documentStyle.bandedCardBorderWidth

    VStack(alignment: .leading, spacing: 0) {
      if showsHeaderBand {
        headerBand
      }
      body(for: content())
    }
    .frame(
      maxWidth: expandsToFillWidth ? .infinity : nil,
      maxHeight: expandsToFillHeight ? .infinity : nil,
      alignment: .top
    )
    .background(style.bodyFill, in: shape)
    .clipShape(shape)
    .overlay {
      if showsOutline {
        shape.strokeBorder(style.outline, lineWidth: strokeWidth)
      }
    }
  }

  private var headerBand: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text(label)
        .documentSectionLabel(accent: true, theme: theme)
      if let accessory, !accessory.isEmpty {
        Spacer(minLength: 4)
        Text(accessory)
          .resolvedInvoiceFont(.meta)
          .foregroundStyle(theme.accentMuted)
          .lineLimit(1)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, InvoiceDocumentDesign.bandPaddingHorizontal)
    .padding(.vertical, InvoiceDocumentDesign.bandPaddingVertical)
    .background(style.bandFill)
    .overlay(alignment: .bottom) {
      if showsOutline {
        Rectangle()
          .fill(style.bandRule)
          .frame(height: documentStyle.bandedCardBorderWidth)
      }
    }
    .previewInspectorTargetIfPresent(inspectorHeaderTarget, interaction: inspectorInteraction)
  }

  private func body(for content: Content) -> some View {
    content
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(flushBody ? 0 : InvoiceDocumentDesign.cardBodyPadding)
  }
}

struct LineItemCellChromeModifier: ViewModifier {
  @Environment(\.invoiceTableStyle) private var tableStyle
  @Environment(\.invoiceTablePresentation) private var presentation
  @Environment(\.invoiceTheme) private var theme

  var isHeader: Bool = false
  var emphasized: Bool = false
  var zebra: Bool = false

  func body(content: Content) -> some View {
    if emphasized, presentation.showsTotalsFill {
      content.background(theme.emphasisFill)
    } else if isHeader, tableStyle.showsHeaderFill, presentation.showsHeaderFill {
      content.background(theme.headerFill)
    } else if zebra, tableStyle.usesZebraRows, presentation.showsZebraRows {
      content.background(InvoiceDocumentDesign.panelFill)
    } else {
      content
    }
  }
}

struct LineItemPreviewTotalsCellBorders: View {
  @Environment(\.invoiceTableStyle) private var tableStyle
  @Environment(\.invoiceTablePresentation) private var presentation
  @Environment(\.invoiceDocumentStyle) private var documentStyle

  var emphasized: Bool = false

  private var bottomColor: Color {
    InvoiceLineItemsTableStyle.borderColor
  }

  private var topColor: Color {
    InvoiceLineItemsTableStyle.emphasisBorderColor
  }

  private var width: CGFloat {
    documentStyle.lineItemsBorderWidth
  }

  var body: some View {
    if tableStyle.showsGridLines, presentation.showsGridLines {
      GeometryReader { geometry in
        let size = geometry.size

        if emphasized {
          Rectangle()
            .fill(topColor)
            .frame(width: size.width, height: width)
            .frame(maxHeight: .infinity, alignment: .top)
        }

        Rectangle()
          .fill(bottomColor)
          .frame(width: size.width, height: width)
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
      .allowsHitTesting(false)
    }
  }
}

struct LineItemPreviewCellBorders: View {
  @Environment(\.invoiceTableStyle) private var tableStyle
  @Environment(\.invoiceTablePresentation) private var presentation
  @Environment(\.invoiceDocumentStyle) private var documentStyle

  let column: LineItemTableColumn
  let isHeader: Bool
  var emphasized: Bool = false

  private var bottomColor: Color {
    isHeader ? InvoiceLineItemsTableStyle.headerBorderColor : InvoiceLineItemsTableStyle.borderColor
  }

  private var topColor: Color {
    InvoiceLineItemsTableStyle.emphasisBorderColor
  }

  private var width: CGFloat {
    documentStyle.lineItemsBorderWidth
  }

  var body: some View {
    if tableStyle.showsGridLines, presentation.showsGridLines {
      GeometryReader { geometry in
        let size = geometry.size

        if emphasized {
          Rectangle()
            .fill(topColor)
            .frame(width: size.width, height: width)
            .frame(maxHeight: .infinity, alignment: .top)
        }

        Rectangle()
          .fill(bottomColor)
          .frame(width: size.width, height: width)
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
      .allowsHitTesting(false)
    }
  }
}

private struct InvoiceTableStyleKey: EnvironmentKey {
  static let defaultValue = InvoiceTableStyle.default
}

private struct InvoiceFontFamilyKey: EnvironmentKey {
  static let defaultValue = InvoiceFontFamilyPreset.default
}

private struct InvoiceBorderWeightKey: EnvironmentKey {
  static let defaultValue = InvoiceBorderWeight.default
}

extension EnvironmentValues {
  var invoiceTableStyle: InvoiceTableStyle {
    get { self[InvoiceTableStyleKey.self] }
    set { self[InvoiceTableStyleKey.self] = newValue }
  }

  var invoiceFontFamily: InvoiceFontFamilyPreset {
    get { self[InvoiceFontFamilyKey.self] }
    set { self[InvoiceFontFamilyKey.self] = newValue }
  }

  var invoiceBorderWeight: InvoiceBorderWeight {
    get { self[InvoiceBorderWeightKey.self] }
    set { self[InvoiceBorderWeightKey.self] = newValue }
  }
}
