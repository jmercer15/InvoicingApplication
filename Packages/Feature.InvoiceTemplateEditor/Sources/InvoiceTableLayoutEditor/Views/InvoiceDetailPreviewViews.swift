import SwiftUI

// MARK: - Invoice Detail Preview Views & Helpers

struct InvoiceDetailsPreviewBlock: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle
  @Environment(\.invoiceFontFamily) private var fontFamily

  let invoiceNumber: String?
  let issueDate: Date
  let dueDate: Date
  var showInvoiceNumber: Bool = true
  var showIssueDate: Bool = true
  var showDueDate: Bool = true
  var dateFormatStyle: InvoiceDateFormatStyle = .default
  var alignsTrailing: Bool = true
  /// Distance the value column (and white surface) extends past its trailing
  /// edge so the cell backgrounds bleed to the physical right page edge on the
  /// wide layout. `0` keeps the table content-hugging (narrow paper / measurer).
  var trailingBleed: CGFloat = 0
  /// Nil in the pagination measurer; the live preview maps individual date
  /// rows to their corresponding DatePickers.
  var showsOutline: Bool = true
  var showsLabels: Bool = true
  var showsGridLines: Bool = true
  var inspectorInteraction: InvoicePreviewInspectorInteraction?

  var body: some View {
    // Tabular metadata rendered as a standalone bordered two-column grid
    // (right-aligned label column + left-aligned value column) so the
    // invoice number and dates read as neatly aligned, visibly ruled rows.
    detailsTable
      .frame(
        maxWidth: alignsTrailing ? nil : .infinity,
        alignment: alignsTrailing ? .trailing : .leading
      )
  }

  /// Bordered two-column table. Cells abut (zero grid spacing) and draw their
  /// own teal grid lines so the row separators and the label/value column
  /// divider stay straight and aligned; an outer accent stroke frames it.
  @ViewBuilder
  private var detailsTable: some View {
    let number = invoiceNumber ?? "—"
    // Square corners on all four edges so the details table reads as a
    // crisp, sharply-ruled block on the banner.
    let shape = Rectangle()
    let strokeWidth = documentStyle.detailsBorderWidth

    Grid(alignment: .trailing, horizontalSpacing: 0, verticalSpacing: 0) {
      if showInvoiceNumber {
        detailRow(
          label: "Invoice #",
          value: number,
          labelColor: theme.accent,
          valueFont: InvoiceDocumentDesign.bodyStrongFont(
            scale: documentStyle.typographyScale, family: fontFamily
          ).monospacedDigit(),
          valueColor: number == "—" ? InvoiceDocumentDesign.inkFaint : theme.accent,
          isFirstRow: true,
          isLastRow: !showIssueDate && !showDueDate
        )
        .previewInspectorTargetIfPresent(.invoiceNumber, interaction: inspectorInteraction)
      }
      if showIssueDate {
        detailRow(
          label: "Issued",
          value: InvoiceDateFormatter.documentString(for: issueDate, style: dateFormatStyle),
          isFirstRow: !showInvoiceNumber,
          isLastRow: !showDueDate
        )
        .previewInspectorTargetIfPresent(.issueDate, interaction: inspectorInteraction)
      }
      if showDueDate {
        detailRow(
          label: "Due",
          value: InvoiceDateFormatter.documentString(for: dueDate, style: dateFormatStyle),
          isFirstRow: !showInvoiceNumber && !showIssueDate,
          isLastRow: true
        )
        .previewInspectorTargetIfPresent(.dueDate, interaction: inspectorInteraction)
      }
    }
    // Size the grid to its natural content width AND height so the whole
    // table hugs its content and does not stretch to fill the header's
    // available width (nor match a taller sibling in the header HStack).
    // The grid resolves each column to its widest content; cells then use
    // maxWidth: .infinity (see detailTableCell) to fill only those
    // content-determined column widths, so the teal grid lines still span
    // the full cell while the table as a whole hugs its content. The value
    // column additionally reserves `trailingBleed` of trailing space so its
    // cell background grows to the right without moving its left-aligned text.
    .fixedSize(horizontal: true, vertical: true)
    // Sit the details card on a crisp white surface so its teal grid lines,
    // labels, and values stay legible on the solid teal header banner.
    .background(InvoiceDetailsTableStyle.surfaceFill, in: shape)
    .clipShape(shape)
    .overlay {
      if showsOutline {
        shape.strokeBorder(
          InvoiceDetailsTableStyle.outerBorderColor(theme: theme),
          lineWidth: strokeWidth
        )
      }
    }
    // Pull the reported layout width back by the bleed so the table stays
    // anchored at the content trailing edge while the extended surface + cells
    // overflow to the right, reaching the page edge on the wide layout.
    .padding(.trailing, -trailingBleed)
  }

  /// One aligned label/value row in the bordered metadata grid. Both cells use
  /// uniform padding and fill the row height so their grid lines line up: the
  /// label cell draws a trailing (column) divider, and every row but the last
  /// draws a bottom (row) separator.
  private func detailRow(
    label: String,
    value: String,
    labelColor: Color? = nil,
    valueFont: Font? = nil,
    valueColor: Color? = nil,
    isFirstRow _: Bool = false,
    isLastRow: Bool = false
  ) -> some View {
    let resolvedLabelColor = labelColor ?? theme.accentMuted
    let valueTrailingBleed = trailingBleed
    return GridRow(alignment: .center) {
      if showsLabels {
        Text(label)
          .resolvedInvoiceFont(.fieldLabel)
          .foregroundStyle(resolvedLabelColor)
          .detailTableCell(
            drawsBottomBorder: showsGridLines && !isLastRow,
            drawsTrailingBorder: showsGridLines,
            alignment: InvoiceDocumentDesign.labelValueLabelAlignment
          )
          .gridColumnAlignment(InvoiceDocumentDesign.labelValueLabelColumnAlignment)
      }
      Text(value)
        .font(
          valueFont
            ?? InvoiceDocumentDesign.bodyFont(
              scale: documentStyle.typographyScale, family: fontFamily)
        )
        .foregroundStyle(
          valueColor
            ?? (value == "—" ? InvoiceDocumentDesign.inkFaint : InvoiceDocumentDesign.ink)
        )
        .lineLimit(1)
        .detailTableCell(
          drawsBottomBorder: showsGridLines && !isLastRow,
          drawsTrailingBorder: false,
          alignment: InvoiceDocumentDesign.labelValueValueAlignment,
          trailingBleed: valueTrailingBleed
        )
        .gridColumnAlignment(InvoiceDocumentDesign.labelValueValueColumnAlignment)
    }
  }
}

/// Visual tokens for the invoice details bordered table. Mirrors the line-items
/// table border language (thin rules) but tinted with the accent so the
/// details card reads as a related, clearly ruled table.
private enum InvoiceDetailsTableStyle {
  static var surfaceFill: Color {
    Color.white
  }

  static let cellHorizontalPadding: CGFloat = 9
  static let cellVerticalPadding: CGFloat = 3

  static func gridLineColor(theme: InvoiceThemePalette) -> Color {
    theme.detailsGridLineColor
  }

  static func outerBorderColor(theme: InvoiceThemePalette) -> Color {
    theme.detailsOuterBorderColor
  }
}

extension View {
  /// Uniform cell padding plus optional teal grid lines (trailing column
  /// divider and bottom row separator), stretched to fill the allocated grid
  /// column width and row height so borders stay straight and span the full
  /// cell across the 2×3 grid.
  fileprivate func detailTableCell(
    drawsBottomBorder: Bool,
    drawsTrailingBorder: Bool,
    alignment: Alignment = .trailing,
    trailingBleed: CGFloat = 0
  ) -> some View {
    padding(.horizontal, InvoiceDetailsTableStyle.cellHorizontalPadding)
      .padding(.vertical, InvoiceDetailsTableStyle.cellVerticalPadding)
      // Reserve trailing space so the value cell's background (and its
      // bottom row separator) extends to the right page edge without
      // shifting the left-aligned text.
      .padding(.trailing, trailingBleed)
      // Fill the allocated grid column width (not just the content width) so
      // the bottom row separator spans the full cell; `alignment` keeps the
      // label trailing-aligned and the value leading-aligned within the cell.
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
      .overlay {
        DetailTableCellBorders(
          drawsBottomBorder: drawsBottomBorder,
          drawsTrailingBorder: drawsTrailingBorder
        )
      }
  }
}

/// Draws the trailing and bottom grid lines for a single details-table cell.
private struct DetailTableCellBorders: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle

  let drawsBottomBorder: Bool
  let drawsTrailingBorder: Bool

  private var width: CGFloat {
    documentStyle.detailsBorderWidth
  }

  var body: some View {
    GeometryReader { geometry in
      let size = geometry.size
      let color = InvoiceDetailsTableStyle.gridLineColor(theme: theme)

      if drawsTrailingBorder {
        Rectangle()
          .fill(color)
          .frame(width: width, height: size.height)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }

      if drawsBottomBorder {
        Rectangle()
          .fill(color)
          .frame(width: size.width, height: width)
          .frame(maxHeight: .infinity, alignment: .bottom)
      }
    }
    .allowsHitTesting(false)
  }
}

struct ThemedDocumentBandedCard<Content: View>: View {
  @Environment(\.invoiceTheme) private var theme

  enum Kind { case party, payment }

  let label: String
  var kind: Kind = .party
  var flushBody: Bool = false
  var showsOutline: Bool = true
  var showsFill: Bool = true
  /// Stretches the card to match a sibling column in an equal-height row.
  var expandsToFillHeight: Bool = false
  var inspectorHeaderTarget: InvoiceInspectorFocusTarget?
  var inspectorInteraction: InvoicePreviewInspectorInteraction?
  @ViewBuilder var content: () -> Content

  private var resolvedStyle: DocumentBandedCardStyle {
    switch kind {
    case .party: .party(theme: theme)
    case .payment: .payment(theme: theme)
    }
  }

  var body: some View {
    DocumentBandedCard(
      label: label,
      style: displayStyle,
      flushBody: flushBody,
      showsOutline: showsOutline,
      expandsToFillHeight: expandsToFillHeight,
      inspectorHeaderTarget: inspectorHeaderTarget,
      inspectorInteraction: inspectorInteraction,
      content: content
    )
  }

  private var displayStyle: DocumentBandedCardStyle {
    guard !showsFill else { return resolvedStyle }
    return DocumentBandedCardStyle(
      bandFill: .clear,
      bodyFill: .clear,
      outline: resolvedStyle.outline,
      bandRule: resolvedStyle.bandRule
    )
  }
}

struct LineItemsSectionTitleView: View {
  @Environment(\.invoiceTheme) private var theme

  var body: some View {
    HStack(spacing: 8) {
      Rectangle()
        .fill(theme.accent)
        .frame(width: 3, height: 12)
      Text("Line Items")
        .documentSectionLabel(accent: true, theme: theme)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

struct TotalsGrandTotalGridRow: View {
  @Environment(\.invoiceTheme) private var theme

  let viewModel: InvoiceEditorViewModel
  let columnWidths: LineItemTableColumnWidths
  let descriptionColumnWidth: CGFloat
  let labelColumnWidth: CGFloat
  let labelRegionWidth: CGFloat
  let labelColumnSpan: Int
  let rowHeight: CGFloat

  var body: some View {
    GridRow {
      if viewModel.columnVisibility.showDate {
        Color.clear
          .lineItemPreviewTotalsEmptyCell(column: .date, width: columnWidths.date)
      }
      Color.clear
        .lineItemPreviewTotalsEmptyCell(column: .description, width: descriptionColumnWidth)
      Color.clear
        .lineItemPreviewTotalsLabelRegionCell(
          regionWidth: labelRegionWidth,
          labelColumnWidth: labelColumnWidth,
          emphasized: true
        ) {
          Text("Total Payable")
            .resolvedInvoiceFont(.emphasis)
            .foregroundStyle(theme.accent)
        }
        .gridCellColumns(max(labelColumnSpan, 1))
      Text(
        InvoiceMoneyFormatter.string(
          for: viewModel.liveTotals.grandTotal,
          currencyCode: viewModel.currencyCode,
          displayStyle: viewModel.currencyDisplayStyle
        )
      )
      .font(
        viewModel.totalsEmphasis.usesCompactType
          ? InvoiceDocumentDesign.bodyEmphasisFont(
            scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
          : InvoiceDocumentDesign.bodyStrongFont(
            scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
      )
      .foregroundStyle(theme.accent)
      .monospacedDigit()
      .lineItemPreviewTotalsValueCell(
        width: columnWidths.total,
        emphasized: true
      )
    }
    .frame(height: rowHeight)
  }
}

struct DocumentTitleUnderlineIfNeeded: ViewModifier {
  let onAccent: Bool
  let showsUnderline: Bool
  let theme: InvoiceThemePalette

  func body(content: Content) -> some View {
    if onAccent || !showsUnderline {
      content
    } else {
      content.documentTitleUnderline(theme: theme)
    }
  }
}

struct PaymentDetailRowView: View {
  @Environment(\.invoiceTheme) private var theme
  @Environment(\.invoiceDocumentStyle) private var documentStyle
  @Environment(\.invoiceFontFamily) private var fontFamily

  let label: String
  let value: String
  let isLast: Bool
  var showsLabel: Bool = true
  var showsRowRule: Bool = true

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      if showsLabel {
        Text(label)
          .font(
            InvoiceDocumentDesign.metaLabelFont(
              scale: documentStyle.typographyScale, family: fontFamily
            ).smallCaps()
          )
          .foregroundStyle(theme.accentMuted)
          .tracking(0.4)
          .multilineTextAlignment(.trailing)
          .frame(
            width: InvoiceDocumentDesign.inlineLabelWidth,
            alignment: InvoiceDocumentDesign.labelValueLabelAlignment
          )
          .lineLimit(1)
          .minimumScaleFactor(0.85)
      }
      Text(value.isEmpty ? "—" : value)
        .resolvedInvoiceFont(.body)
        .foregroundStyle(value.isEmpty ? InvoiceDocumentDesign.inkFaint : InvoiceDocumentDesign.ink)
        .lineLimit(1)
        .frame(
          maxWidth: .infinity,
          alignment: InvoiceDocumentDesign.labelValueValueAlignment
        )
    }
    .padding(.horizontal, InvoiceDocumentDesign.bandPaddingHorizontal)
    .padding(.vertical, InvoiceDocumentLayout.footerRowSpacing * documentStyle.spacingScale)
    .overlay(alignment: .bottom) {
      if showsRowRule && !isLast {
        Rectangle()
          .fill(theme.paymentRowRule)
          .frame(height: InvoiceDocumentDesign.bandedCardBorderWidth)
      }
    }
  }
}
