import Core
import CoreGraphics
import SwiftUI

/// Shared visual tokens for the printable invoice document.
enum InvoiceDocumentDesign {
  // MARK: - Color

  /// Restrained brand accent — deep teal, print-safe on white.
  static let accent = Color(red: 0.13, green: 0.36, blue: 0.40)

  static let ink = Color.primary
  /// Supporting text on the always-light printable page. At 55% primary over white,
  /// this remains above the 4.5:1 small-text contrast target.
  static let inkMuted = Color.primary.opacity(0.55)
  /// Empty-state values still appear in the document preview and must remain readable.
  /// Use the same contrast-safe tone as supporting text rather than a decorative faint tint.
  static let inkFaint = inkMuted
  static let stroke = Color.primary.opacity(0.1)
  static let strokeStrong = Color.primary.opacity(0.18)
  static let panelFill = Color.primary.opacity(0.02)
  static let pageNumberBackground = Color.primary.opacity(0.04)

  // MARK: - Banded card

  /// Tinted header band behind a party card's section label.
  static let partyBandFill = accent.opacity(0.08)
  /// Faint body surface for a party card.
  static let partyBodyFill = Color.primary.opacity(0.012)
  /// Soft outline framing a party card.
  static let partyCardOutline = accent.opacity(0.22)
  /// Rule dividing a party card's header band from its body.
  static let partyBandRule = accent.opacity(0.22)

  /// Near-white body surface so the payment footer reads as crisp ruled tables.
  static let paymentBodyFill = Color.primary.opacity(0.02)
  // MARK: - Layout

  /// Horizontal inset for a banded card's header label.
  static let bandPaddingHorizontal: CGFloat = 10
  /// Vertical inset for a banded card's header label.
  static let bandPaddingVertical: CGFloat = 3
  /// Body inset inside a banded card.
  static let cardBodyPadding: CGFloat = 7
  /// Thin rules used for a banded card's outline and header divider.
  static let bandedCardBorderWidth: CGFloat = 1
  /// Horizontal inset for the document header banner content (kept comfortable).
  static let bannerPaddingHorizontal: CGFloat = 14
  /// Vertical inset for the document header banner content (zero — banner hugs content).
  static let bannerPaddingVertical: CGFloat = 0
  static let inlineLabelWidth: CGFloat = 56
  /// Label/value pair grids (invoice details, party contact, payment details):
  /// labels sit trailing toward the values; values sit leading in their column.
  /// Line-item Qty/Rate/Amount and totals currency cells stay trailing separately.
  static let labelValueLabelAlignment: Alignment = .trailing
  static let labelValueValueAlignment: Alignment = .leading
  static let labelValueLabelColumnAlignment: HorizontalAlignment = .trailing
  static let labelValueValueColumnAlignment: HorizontalAlignment = .leading
  static let cardBorderWidth: CGFloat = 0.5
  static let titleUnderlineHeight: CGFloat = 2.5
  static let titleUnderlineWidth: CGFloat = 48

  // MARK: - Typography

  //
  // Document preview type scale (see `InvoiceLineItemsTypography` for sizes):
  //   Display  — banner title (dynamic scale, 40/48 pt cap)
  //   Heading  — section labels (From, Line Items, banded card headers)
  //   Body     — primary content (names, amounts, table cells)
  //   Meta     — secondary info (field labels, contact details, item codes)
  // Emphasis uses weight within Body/Meta — not ad-hoc size jumps.

  /// Large *base* (maximum) title size. The rendered title scales down from
  /// this to fit the available banner width on one line, so it fills the space
  /// left of the invoice details table while never exceeding this cap.
  static let titleSizeWide: CGFloat = 48
  static let titleSizeNarrow: CGFloat = 40
  static let titleTracking: CGFloat = -0.4
  /// Lowest scale the dynamic title shrinks to before truncating, so long
  /// titles still fit on a single (height-stable) line.
  static let titleMinimumScaleFactor: CGFloat = 0.2

  static func documentTitleFont(
    wide: Bool,
    scale: CGFloat,
    family: InvoiceFontFamilyPreset = .default
  ) -> Font {
    family.font(
      size: wide
        ? InvoiceLineItemsTypography.titleSizeWide(scale: scale)
        : InvoiceLineItemsTypography.titleSizeNarrow(scale: scale),
      weight: .bold
    )
  }

  /// Section headings (small-caps labels above party cards, payment footer, etc.).
  static var headingFont: Font {
    .system(size: InvoiceLineItemsTypography.headingFontSize, weight: .semibold)
  }

  static var sectionLabelFont: Font {
    headingFont
  }

  /// Inline field labels in ruled tables (details, totals, contact grid).
  static var metaLabelFont: Font {
    .system(size: InvoiceLineItemsTypography.metaFontSize, weight: .medium)
  }

  /// Page chrome outside the printable area (page count, paper size label).
  static var chromeFont: Font {
    metaLabelFont
  }

  static func bodyFont(scale: CGFloat, family: InvoiceFontFamilyPreset = .default) -> Font {
    family.font(size: InvoiceLineItemsTypography.bodyFontSize(scale: scale))
  }

  static func bodyEmphasisFont(scale: CGFloat, family: InvoiceFontFamilyPreset = .default) -> Font {
    family.font(size: InvoiceLineItemsTypography.bodyFontSize(scale: scale), weight: .semibold)
  }

  static func bodyStrongFont(scale: CGFloat, family: InvoiceFontFamilyPreset = .default) -> Font {
    family.font(size: InvoiceLineItemsTypography.bodyFontSize(scale: scale), weight: .bold)
  }

  static func tableHeaderFont(scale: CGFloat, family: InvoiceFontFamilyPreset = .default) -> Font {
    bodyStrongFont(scale: scale, family: family)
  }

  static func metaFont(scale: CGFloat, family: InvoiceFontFamilyPreset = .default) -> Font {
    family.font(size: InvoiceLineItemsTypography.metaFontSize(scale: scale))
  }

  static func metaLabelFont(scale: CGFloat, family: InvoiceFontFamilyPreset = .default) -> Font {
    family.font(size: InvoiceLineItemsTypography.metaFontSize(scale: scale), weight: .medium)
  }
}
/// Formats monetary amounts as `$` + grouped value; omits decimal places for whole numbers.

/// Fixed typography for invoice line-items table content in the document preview.
///
/// Type scale: Display (40/48) · Heading 10 · Body 11 · Meta 9.
enum InvoiceLineItemsTypography {
  /// Section headings — distinct from body, below display title.
  static let headingFontSize: CGFloat = 10
  /// Primary document content.
  static let bodyFontSize: CGFloat = 11
  /// Secondary labels and supporting text.
  /// macOS HIG minimum for legible custom text.
  static let metaFontSize: CGFloat = 10

  static func scaledSize(_ base: CGFloat, density: InvoiceTypographyDensity) -> CGFloat {
    scaledSize(base, scale: density.scale)
  }

  static func scaledSize(_ base: CGFloat, scale: CGFloat) -> CGFloat {
    // Keep all custom document text at or above the macOS legibility floor,
    // even when a user chooses a compact presentation scale.
    max(10, (base * scale).rounded(.toNearestOrAwayFromZero))
  }

  static func bodyFontSize(for density: InvoiceTypographyDensity) -> CGFloat {
    scaledSize(bodyFontSize, density: density)
  }

  static func bodyFontSize(scale: CGFloat) -> CGFloat {
    scaledSize(bodyFontSize, scale: scale)
  }

  static func metaFontSize(scale: CGFloat) -> CGFloat {
    scaledSize(metaFontSize, scale: scale)
  }

  static func metaFontSize(for density: InvoiceTypographyDensity) -> CGFloat {
    scaledSize(metaFontSize, density: density)
  }

  static func titleSizeWide(scale: CGFloat) -> CGFloat {
    scaledSize(InvoiceDocumentDesign.titleSizeWide, scale: scale)
  }

  static func titleSizeNarrow(scale: CGFloat) -> CGFloat {
    scaledSize(InvoiceDocumentDesign.titleSizeNarrow, scale: scale)
  }

  /// A4 portrait content width (page width minus standard margins).
  static var referenceContentWidth: CGFloat {
    PaperSize.a4.portraitSizePoints.width - (2 * PaperSize.a4.marginPoints)
  }

  /// Preview fit scale used by `InvoiceEditorView` (`min(availableWidth / pageWidth, 1)`).
  static func previewScale(availableWidth: CGFloat, pageWidth: CGFloat) -> CGFloat {
    guard pageWidth > 0 else { return 1 }
    return min(max(availableWidth, 1) / pageWidth, 1)
  }

  /// Printable content width for the active page (page width minus both margins).
  static func contentWidth(pageWidth: CGFloat, margin: CGFloat) -> CGFloat {
    max(pageWidth - (margin * 2), 1)
  }
}

/// Shared visual tokens for the preview line-items `Grid` table.
enum InvoiceLineItemsTableStyle {
  static var borderColor: Color {
    InvoiceDocumentDesign.stroke
  }

  static var headerBorderColor: Color {
    InvoiceDocumentDesign.accent.opacity(0.32)
  }

  static var emphasisBorderColor: Color {
    InvoiceDocumentDesign.accent.opacity(0.35)
  }

  static let cellHorizontalPadding: CGFloat = 6
  static let cellVerticalPadding: CGFloat = 3
  /// Extra vertical inset for the column-header row only (body cells stay at `cellVerticalPadding`).
  static let headerCellVerticalPadding: CGFloat = 5
  /// Light tracking so short header labels read as labels, not body copy.
  static let headerTracking: CGFloat = 0.35

  static var cellHorizontalInset: CGFloat {
    cellHorizontalPadding * 2
  }

  static var cellVerticalInset: CGFloat {
    cellVerticalPadding * 2
  }

  static var headerCellVerticalInset: CGFloat {
    headerCellVerticalPadding * 2
  }
}

extension View {
  /// Small-caps section label used across the document.
  func documentSectionLabel(accent: Bool = false, theme: InvoiceThemePalette = .default)
    -> some View
  {
    font(InvoiceDocumentDesign.sectionLabelFont.smallCaps())
      .foregroundStyle(accent ? theme.accentMuted : InvoiceDocumentDesign.inkMuted)
      .tracking(0.55)
  }

  /// Accent underline beneath the document title.
  func documentTitleUnderline(theme: InvoiceThemePalette = .default) -> some View {
    padding(.top, 2)
      .overlay(alignment: .bottomLeading) {
        Rectangle()
          .fill(theme.accent)
          .frame(
            width: InvoiceDocumentDesign.titleUnderlineWidth,
            height: InvoiceDocumentDesign.titleUnderlineHeight
          )
          .offset(y: InvoiceDocumentDesign.titleUnderlineHeight)
      }
      .padding(.bottom, InvoiceDocumentDesign.titleUnderlineHeight)
  }

  /// Square badge for page chrome outside the printable area.
  func documentChromeCapsule(horizontalPadding: CGFloat = 10, verticalPadding: CGFloat = 4)
    -> some View
  {
    padding(.horizontal, horizontalPadding)
      .padding(.vertical, verticalPadding)
      .background(InvoiceDocumentDesign.pageNumberBackground, in: Rectangle())
      .overlay {
        Rectangle()
          .strokeBorder(
            InvoiceDocumentDesign.stroke, lineWidth: InvoiceDocumentDesign.cardBorderWidth)
      }
  }

  /// Padding and grid-line borders for a preview totals value cell aligned to the Total column.
  func lineItemPreviewTotalsValueCell(
    alignment: Alignment = .trailing,
    width: CGFloat,
    emphasized: Bool = false
  ) -> some View {
    padding(.horizontal, InvoiceLineItemsTableStyle.cellHorizontalPadding)
      .padding(.vertical, InvoiceLineItemsTableStyle.cellVerticalPadding)
      .frame(width: width, alignment: alignment)
      .frame(maxHeight: .infinity, alignment: alignment)
      .cellChrome(emphasized: emphasized)
      .overlay {
        LineItemPreviewTotalsCellBorders(emphasized: emphasized)
      }
  }

  /// Padding and grid-line borders for the qty+unit+rate region that hosts a trailing,
  /// content-hugging totals label immediately left of the value column.
  func lineItemPreviewTotalsLabelRegionCell(
    regionWidth: CGFloat,
    labelColumnWidth: CGFloat,
    emphasized: Bool = false,
    @ViewBuilder label: () -> some View
  ) -> some View {
    HStack(spacing: 0) {
      Color.clear
        .frame(maxWidth: .infinity)
      label()
        .padding(.horizontal, InvoiceLineItemsTableStyle.cellHorizontalPadding)
        .frame(width: labelColumnWidth, alignment: .trailing)
    }
    .padding(.vertical, InvoiceLineItemsTableStyle.cellVerticalPadding)
    .frame(width: regionWidth, alignment: .trailing)
    .frame(maxHeight: .infinity, alignment: .trailing)
    .cellChrome(emphasized: emphasized)
    .overlay {
      LineItemPreviewTotalsCellBorders(emphasized: emphasized)
    }
  }

  /// Padding and frame for empty Date / Description cells in the totals grid.
  ///
  /// Omits internal grid lines so placeholder columns stay visually open.
  @ViewBuilder
  func lineItemPreviewTotalsEmptyCell(
    column _: LineItemTableColumn,
    width: CGFloat? = nil,
    expandsHorizontally: Bool = false
  ) -> some View {
    let padded = padding(.horizontal, InvoiceLineItemsTableStyle.cellHorizontalPadding)
      .padding(.vertical, InvoiceLineItemsTableStyle.cellVerticalPadding)

    Group {
      if let width {
        padded
          .frame(width: width, alignment: .leading)
          .frame(maxHeight: .infinity, alignment: .leading)
      } else {
        padded
          .frame(
            maxWidth: expandsHorizontally ? .infinity : nil,
            maxHeight: .infinity,
            alignment: .leading
          )
      }
    }
  }

  /// Padding and grid-line borders for a preview line-items table cell.
  ///
  /// Content is padded first, then given a cell frame so borders span the allocated
  /// column width. Shrink columns pass an explicit measured `width`; Description
  /// sets `expandsHorizontally` so it flexes within `contentWidth`.
  @ViewBuilder
  func lineItemPreviewGridCell(
    column: LineItemTableColumn,
    isHeader: Bool = false,
    alignment: Alignment = .leading,
    width: CGFloat? = nil,
    expandsHorizontally: Bool = false,
    emphasized: Bool = false,
    zebra: Bool = false
  ) -> some View {
    let verticalPadding =
      isHeader
      ? InvoiceLineItemsTableStyle.headerCellVerticalPadding
      : InvoiceLineItemsTableStyle.cellVerticalPadding
    let padded = padding(.horizontal, InvoiceLineItemsTableStyle.cellHorizontalPadding)
      .padding(.vertical, verticalPadding)

    Group {
      if let width {
        padded
          .frame(width: width, alignment: alignment)
          .frame(maxHeight: .infinity, alignment: alignment)
          .clipped()
      } else {
        padded
          .frame(
            maxWidth: expandsHorizontally ? .infinity : nil,
            maxHeight: .infinity,
            alignment: alignment
          )
      }
    }
    .cellChrome(isHeader: isHeader, emphasized: emphasized, zebra: zebra)
    .overlay {
      LineItemPreviewCellBorders(column: column, isHeader: isHeader, emphasized: emphasized)
    }
  }

  func cellChrome(isHeader: Bool = false, emphasized: Bool = false, zebra: Bool = false)
    -> some View
  {
    modifier(LineItemCellChromeModifier(isHeader: isHeader, emphasized: emphasized, zebra: zebra))
  }
}
