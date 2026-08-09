import Core
import CoreGraphics
import Foundation
import SwiftUI

/// Resolved accent-derived colors for a single invoice document render pass.
struct InvoiceThemePalette: Equatable {
  let accent: Color
  /// Whether black content yields greater contrast than white on the accent banner.
  let usesDarkOnAccentContent: Bool

  init(accent: Color, usesDarkOnAccentContent: Bool = false) {
    self.accent = accent
    self.usesDarkOnAccentContent = usesDarkOnAccentContent
  }

  init(customAccentColor: InvoiceCustomAccentColor) {
    self.init(
      accent: Color(
        red: customAccentColor.red,
        green: customAccentColor.green,
        blue: customAccentColor.blue,
        opacity: customAccentColor.opacity
      ),
      usesDarkOnAccentContent: Self.prefersDarkContent(on: customAccentColor)
    )
  }

  static let `default` = InvoiceAccentTheme.default.palette

  var accentMuted: Color {
    accent.opacity(0.72)
  }

  var accentEmphasisTint: Color {
    accent.opacity(0.09)
  }

  /// Stronger tint behind line-items column headers (ruled table style).
  var tableHeaderFill: Color {
    accent.opacity(0.12)
  }

  var partyBandFill: Color {
    accent.opacity(0.08)
  }

  var partyCardOutline: Color {
    accent.opacity(0.22)
  }

  var partyBandRule: Color {
    accent.opacity(0.22)
  }

  var paymentBandFill: Color {
    accent.opacity(0.11)
  }

  var paymentCardOutline: Color {
    accent.opacity(0.42)
  }

  var paymentBandRule: Color {
    accent.opacity(0.42)
  }

  var paymentRowRule: Color {
    accent.opacity(0.14)
  }

  var bannerFill: Color {
    accent
  }

  /// Text and strokes on the printable accent banner always use the higher-contrast
  /// of opaque black and white. This matters most for arbitrary user-selected accents:
  /// partially transparent small text can fall below macOS's 4.5:1 contrast target,
  /// even when the underlying black-or-white choice is correct.
  var onAccentText: Color {
    usesDarkOnAccentContent ? .black : .white
  }

  /// Keep secondary accent-banner text at the same contrast-safe foreground tone.
  /// Hierarchy comes from its native font role and supporting placement, rather than
  /// a transparency reduction that can make custom-accent text illegible.
  var onAccentTextMuted: Color {
    onAccentText
  }

  var onAccentStroke: Color {
    usesDarkOnAccentContent ? .black.opacity(0.42) : .white.opacity(0.5)
  }

  var onAccentSurface: Color {
    usesDarkOnAccentContent ? .black.opacity(0.08) : .white.opacity(0.12)
  }

  var headerFill: Color {
    tableHeaderFill
  }

  var emphasisFill: Color {
    accentEmphasisTint
  }

  var detailsGridLineColor: Color {
    accent.opacity(0.35)
  }

  var detailsOuterBorderColor: Color {
    accent.opacity(0.5)
  }

  private static func prefersDarkContent(on color: InvoiceCustomAccentColor) -> Bool {
    // The document banner prints over a white page. Composite a translucent
    // custom color over that page before comparing standard WCAG contrast ratios.
    let alpha = color.opacity.clamped(to: 0...1)
    let red = color.red * alpha + (1 - alpha)
    let green = color.green * alpha + (1 - alpha)
    let blue = color.blue * alpha + (1 - alpha)
    let luminance =
      0.2126 * linearized(red)
      + 0.7152 * linearized(green)
      + 0.0722 * linearized(blue)
    let whiteContrast = 1.05 / (luminance + 0.05)
    let blackContrast = (luminance + 0.05) / 0.05
    return blackContrast > whiteContrast
  }

  private static func linearized(_ component: Double) -> Double {
    let value = component.clamped(to: 0...1)
    return value <= 0.04045
      ? value / 12.92
      : pow((value + 0.055) / 1.055, 2.4)
  }
}

extension Double {
  fileprivate func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}

extension InvoiceAccentTheme {
  var palette: InvoiceThemePalette {
    InvoiceThemePalette(accent: accentColor)
  }
}

private struct InvoiceThemeKey: EnvironmentKey {
  static let defaultValue = InvoiceThemePalette.default
}

struct InvoiceDocumentResolvedStyle: Equatable {
  var typographyScale: CGFloat
  var spacingScale: CGFloat
  /// Baseline stroke used by details tables and banded cards.
  var borderWidth: CGFloat

  var lineItemsBorderWidth: CGFloat {
    max(0.1, borderWidth * 0.5)
  }

  var detailsBorderWidth: CGFloat {
    max(0.1, borderWidth)
  }

  var bandedCardBorderWidth: CGFloat {
    max(0.1, borderWidth)
  }

  static let `default` = InvoiceDocumentResolvedStyle(
    typographyScale: InvoiceTypographyDensity.default.scale,
    spacingScale: InvoiceDocumentSpacingPreset.default.scale,
    borderWidth: InvoiceBorderWeight.default.detailsBorderWidth
  )
}

private struct InvoiceDocumentResolvedStyleKey: EnvironmentKey {
  static let defaultValue = InvoiceDocumentResolvedStyle.default
}

struct InvoiceTablePresentation: Equatable {
  var showsGridLines: Bool = true
  var showsZebraRows: Bool = true
  var showsHeaderFill: Bool = true
  var showsTotalsFill: Bool = true
}

private struct InvoiceTablePresentationKey: EnvironmentKey {
  static let defaultValue = InvoiceTablePresentation()
}

extension EnvironmentValues {
  var invoiceTheme: InvoiceThemePalette {
    get { self[InvoiceThemeKey.self] }
    set { self[InvoiceThemeKey.self] = newValue }
  }

  var invoiceDocumentStyle: InvoiceDocumentResolvedStyle {
    get { self[InvoiceDocumentResolvedStyleKey.self] }
    set { self[InvoiceDocumentResolvedStyleKey.self] = newValue }
  }

  var invoiceTablePresentation: InvoiceTablePresentation {
    get { self[InvoiceTablePresentationKey.self] }
    set { self[InvoiceTablePresentationKey.self] = newValue }
  }
}

extension View {
  func resolvedInvoiceFont(_ role: ResolvedInvoiceFontRole) -> some View {
    modifier(ResolvedInvoiceFontModifier(role: role))
  }

  func invoiceTheme(_ palette: InvoiceThemePalette) -> some View {
    environment(\.invoiceTheme, palette)
  }

  func invoiceTableStyle(_ style: InvoiceTableStyle) -> some View {
    environment(\.invoiceTableStyle, style)
  }

  func invoiceFontFamily(_ family: InvoiceFontFamilyPreset) -> some View {
    environment(\.invoiceFontFamily, family)
  }

  func invoiceBorderWeight(_ weight: InvoiceBorderWeight) -> some View {
    environment(\.invoiceBorderWeight, weight)
  }

  func invoiceTemplateAppearance(
    theme: InvoiceThemePalette,
    tableStyle: InvoiceTableStyle,
    fontFamily: InvoiceFontFamilyPreset,
    borderWeight: InvoiceBorderWeight = .default,
    tablePresentation: InvoiceTablePresentation = .init(),
    resolvedStyle: InvoiceDocumentResolvedStyle = .default
  ) -> some View {
    invoiceTheme(theme)
      .invoiceTableStyle(tableStyle)
      .invoiceFontFamily(fontFamily)
      .invoiceBorderWeight(borderWeight)
      .environment(\.invoiceTablePresentation, tablePresentation)
      .environment(\.invoiceDocumentStyle, resolvedStyle)
  }
}

enum ResolvedInvoiceFontRole {
  case body, emphasis, meta, fieldLabel
}

private struct ResolvedInvoiceFontModifier: ViewModifier {
  @Environment(\.invoiceDocumentStyle) private var style
  @Environment(\.invoiceFontFamily) private var family
  let role: ResolvedInvoiceFontRole

  func body(content: Content) -> some View {
    content.font(font)
  }

  private var font: Font {
    switch role {
    case .body: InvoiceDocumentDesign.bodyFont(scale: style.typographyScale, family: family)
    case .emphasis:
      InvoiceDocumentDesign.bodyEmphasisFont(scale: style.typographyScale, family: family)
    case .meta: InvoiceDocumentDesign.metaFont(scale: style.typographyScale, family: family)
    case .fieldLabel:
      InvoiceDocumentDesign.metaLabelFont(scale: style.typographyScale, family: family)
    }
  }
}

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
enum InvoiceMoneyFormatter {
  private static let fractionDigits = 2

  private static let wholeNumberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    formatter.usesGroupingSeparator = true
    return formatter
  }()

  private static let fractionalFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = fractionDigits
    formatter.maximumFractionDigits = fractionDigits
    formatter.usesGroupingSeparator = true
    return formatter
  }()

  static func rounded(_ amount: Decimal) -> Decimal {
    InvoiceCalculations.currencyRounded(amount)
  }

  private static func isWholeNumber(_ amount: Decimal) -> Bool {
    var value = amount
    var truncated = Decimal()
    NSDecimalRound(&truncated, &value, 0, .down)
    return amount == truncated
  }

  private static func numericString(for roundedAmount: Decimal) -> String {
    let formatter = isWholeNumber(roundedAmount) ? wholeNumberFormatter : fractionalFormatter
    let fallback = isWholeNumber(roundedAmount) ? "0" : "0.00"
    return formatter.string(from: NSDecimalNumber(decimal: roundedAmount)) ?? fallback
  }

  static func string(
    for amount: Decimal,
    currencyCode: String = InvoiceCurrencyCode.defaultValue,
    displayStyle: InvoiceCurrencyDisplayStyle = .default
  ) -> String {
    let roundedAmount = rounded(amount)
    let numeric = numericString(for: roundedAmount)
    let code = InvoiceCurrencyCode.normalizedOrDefault(currencyCode)

    switch displayStyle {
    case .symbol:
      if code == "USD" {
        return "$\(numeric)"
      }
      return currencyString(for: roundedAmount, currencyCode: code)
    case .code:
      return "\(code) \(numeric)"
    case .iso:
      return "\(numeric) \(code)"
    }
  }

  static func editablePrefix(
    currencyCode: String,
    displayStyle: InvoiceCurrencyDisplayStyle
  ) -> String? {
    switch displayStyle {
    case .symbol:
      currencySymbol(for: currencyCode)
    case .code:
      InvoiceCurrencyCode.normalizedOrDefault(currencyCode)
    case .iso:
      nil
    }
  }

  static func editableSuffix(
    currencyCode: String,
    displayStyle: InvoiceCurrencyDisplayStyle
  ) -> String? {
    displayStyle == .iso ? InvoiceCurrencyCode.normalizedOrDefault(currencyCode) : nil
  }

  private static func currencySymbol(for currencyCode: String) -> String {
    let code = InvoiceCurrencyCode.normalizedOrDefault(currencyCode)
    if code == "USD" { return "$" }

    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = code
    return formatter.currencySymbol ?? code
  }

  private static func currencyString(for roundedAmount: Decimal, currencyCode: String) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currencyCode.uppercased()
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = fractionDigits
    formatter.usesGroupingSeparator = true
    let fallback = numericString(for: roundedAmount)
    return formatter.string(from: NSDecimalNumber(decimal: roundedAmount)) ?? fallback
  }

  /// Numeric portion for editable money fields; `$` is shown as a separate prefix.
  static func editableString(for amount: Decimal) -> String {
    numericString(for: rounded(amount))
  }
}

/// Display string for non-monetary decimal fields (quantity, percentages).
enum InvoiceDecimalFormatter {
  static func string(for value: Decimal, locale: Locale = .current) -> String {
    let formatter = NumberFormatter()
    formatter.locale = locale
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = false
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 16
    return formatter.string(from: NSDecimalNumber(decimal: value))
      ?? NSDecimalNumber(decimal: value).stringValue
  }
}

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

  static let cellHorizontalPadding: CGFloat = 10
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

/// Visual recipe for a `DocumentBandedCard`. Two presets keep the party blocks
/// and the payment footer cohesive (shared header-band language) while reading
/// as distinct families: soft outlined party cards vs. crisper ruled payment
/// tables.
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

private struct LineItemCellChromeModifier: ViewModifier {
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

private struct LineItemPreviewTotalsCellBorders: View {
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

private struct LineItemPreviewCellBorders: View {
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

enum InvoiceDateFormatter {
  private static let mediumFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
  }()

  private static let shortFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .none
    return formatter
  }()

  private static let longFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .none
    return formatter
  }()

  /// Display string for document metadata and line-item date columns.
  static func documentString(for date: Date, style: InvoiceDateFormatStyle) -> String {
    switch style {
    case .medium: mediumFormatter.string(from: date)
    case .short: shortFormatter.string(from: date)
    case .long: longFormatter.string(from: date)
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
