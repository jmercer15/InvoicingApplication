import SwiftUI

extension InvoiceDocumentSections {
  // MARK: - Totals & footer

  /// Totals rows for the unified line-items preview grid (Date | Description | Qty | Unit | Rate | Total).
  @ViewBuilder
  static func totalsGridRows(
    viewModel: InvoiceEditorViewModel,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    rowHeight: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let emphasis = viewModel.totalsEmphasis
    let amountFont: Font =
      emphasis.usesCompactType
      ? InvoiceDocumentDesign.metaFont(
        scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
      : InvoiceDocumentDesign.bodyFont(
        scale: viewModel.resolvedDocumentStyle.typographyScale, family: viewModel.fontFamily)
    let emphasizeRows = emphasis.emphasizesAllRows
    let labelColumnWidth = LineItemColumnWidthMeasurer.measureTotalsLabelWidth(
      density: viewModel.typographyDensity,
      typographyScale: viewModel.resolvedDocumentStyle.typographyScale
    )
    let labelRegionWidth = columnWidths.qtyUnitRateWidth
    let labelColumnSpan = viewModel.columnVisibility.totalsLabelColumnSpan

    let discountValue = InvoiceCalculations.discountValue(
      subtotal: viewModel.liveTotals.subtotal,
      discountAmount: viewModel.discountAmount,
      discountPercent: viewModel.discountPercent
    )

    totalsAmountGridRow(
      label: "Subtotal",
      amount: viewModel.liveTotals.subtotal,
      amountFont: amountFont,
      currencyCode: viewModel.currencyCode,
      columnWidths: columnWidths,
      descriptionColumnWidth: descriptionColumnWidth,
      labelColumnWidth: labelColumnWidth,
      labelRegionWidth: labelRegionWidth,
      labelColumnSpan: labelColumnSpan,
      rowHeight: rowHeight,
      visibility: viewModel.columnVisibility,
      currencyDisplayStyle: viewModel.currencyDisplayStyle,
      emphasized: emphasizeRows
    )
    .previewInspectorTargetIfPresent(.currencyCode, interaction: inspectorInteraction)

    if viewModel.discountPercent != 0 {
      totalsRateValueGridRow(
        label: "Disc %",
        value: "\(InvoiceDecimalFormatter.string(for: viewModel.discountPercent))%",
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        font: amountFont,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        emphasized: emphasizeRows
      )
      .previewInspectorTargetIfPresent(.discountPercent, interaction: inspectorInteraction)
    }

    if discountValue != 0 {
      totalsAmountGridRow(
        label: "Discount",
        amount: discountValue,
        amountFont: amountFont,
        currencyCode: viewModel.currencyCode,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        currencyDisplayStyle: viewModel.currencyDisplayStyle,
        emphasized: emphasizeRows
      )
      .previewInspectorTargetIfPresent(.discountAmount, interaction: inspectorInteraction)
    }

    if viewModel.showsTaxSummary {
      if viewModel.liveTotals.taxTotal != 0 {
        totalsAmountGridRow(
        label: viewModel.taxLabelStyle.appliedLabel,
        amount: viewModel.liveTotals.taxTotal,
        amountFont: amountFont,
        currencyCode: viewModel.currencyCode,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        currencyDisplayStyle: viewModel.currencyDisplayStyle,
        emphasized: emphasizeRows
        )
        .previewInspectorTargetIfPresent(.defaultTaxRate, interaction: inspectorInteraction)
      } else {
        totalsRateValueGridRow(
        label: viewModel.taxLabelStyle.appliedLabel,
        value: viewModel.taxLabelStyle.zeroTaxLabel,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        font: amountFont,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        emphasized: emphasizeRows
        )
        .previewInspectorTargetIfPresent(.defaultTaxRate, interaction: inspectorInteraction)
      }
    }

    if viewModel.creditApplied != 0 {
      totalsAmountGridRow(
        label: "Credit",
        amount: viewModel.creditApplied,
        amountFont: amountFont,
        currencyCode: viewModel.currencyCode,
        columnWidths: columnWidths,
        descriptionColumnWidth: descriptionColumnWidth,
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        labelColumnSpan: labelColumnSpan,
        rowHeight: rowHeight,
        visibility: viewModel.columnVisibility,
        currencyDisplayStyle: viewModel.currencyDisplayStyle,
        emphasized: emphasizeRows
      )
      .previewInspectorTargetIfPresent(.creditApplied, interaction: inspectorInteraction)
    }

    totalsGrandTotalGridRow(
      viewModel: viewModel,
      columnWidths: columnWidths,
      descriptionColumnWidth: descriptionColumnWidth,
      labelColumnWidth: labelColumnWidth,
      labelRegionWidth: labelRegionWidth,
      rowHeight: rowHeight
    )
  }

  /// Payment details and payment terms — pinned to the bottom of the last page in preview.
  @ViewBuilder
  static func documentPaymentFooter(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let sideBySide = viewModel.partyLayout.usesSideBySide(contentWidth: contentWidth)
    let showsDetails = viewModel.showPaymentDetails
    let showsTerms = viewModel.showPaymentTerms

    if !showsDetails, !showsTerms {
      EmptyView()
    } else if showsDetails, showsTerms {
      if sideBySide {
        // Equalize to the taller card only. `.fixedSize(vertical: true)`
        // keeps the row from growing into leftover page space offered by
        // the footer Spacer that pins this block to the page bottom.
        HStack(
          alignment: .top,
          spacing: InvoiceDocumentLayout.partyColumnSpacing(
            scale: viewModel.resolvedDocumentStyle.spacingScale)
        ) {
          paymentDetailsCard(
            viewModel: viewModel, expandsToFillHeight: true,
            showsOutline: viewModel.showPaymentCardBorders,
            showsFill: viewModel.showPaymentCardFill,
            showsLabels: viewModel.showPaymentDetailLabels,
            showsRowRules: viewModel.showPaymentDetailRowRules,
            inspectorInteraction: inspectorInteraction
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
          paymentTermsCard(
            terms: viewModel.paymentTerms, notes: viewModel.notes, expandsToFillHeight: true,
            showsOutline: viewModel.showPaymentCardBorders, showsFill: viewModel.showPaymentCardFill
          )
          .previewInspectorTargetIfPresent(.paymentTerms, interaction: inspectorInteraction)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .fixedSize(horizontal: false, vertical: true)
      } else {
        VStack(
          alignment: .leading,
          spacing: InvoiceDocumentLayout.footerSpacing(
            scale: viewModel.resolvedDocumentStyle.spacingScale)
        ) {
          paymentDetailsCard(
            viewModel: viewModel, showsOutline: viewModel.showPaymentCardBorders,
            showsFill: viewModel.showPaymentCardFill,
            showsLabels: viewModel.showPaymentDetailLabels,
            showsRowRules: viewModel.showPaymentDetailRowRules,
            inspectorInteraction: inspectorInteraction)
          paymentTermsCard(
            terms: viewModel.paymentTerms, notes: viewModel.notes,
            showsOutline: viewModel.showPaymentCardBorders,
            showsFill: viewModel.showPaymentCardFill
          )
          .previewInspectorTargetIfPresent(.paymentTerms, interaction: inspectorInteraction)
        }
      }
    } else if showsDetails {
      paymentDetailsCard(
        viewModel: viewModel, showsOutline: viewModel.showPaymentCardBorders,
        showsFill: viewModel.showPaymentCardFill, showsLabels: viewModel.showPaymentDetailLabels,
        showsRowRules: viewModel.showPaymentDetailRowRules,
        inspectorInteraction: inspectorInteraction)
    } else {
      paymentTermsCard(
        terms: viewModel.paymentTerms, notes: viewModel.notes,
        showsOutline: viewModel.showPaymentCardBorders,
        showsFill: viewModel.showPaymentCardFill
      )
      .previewInspectorTargetIfPresent(.paymentTerms, interaction: inspectorInteraction)
    }
  }

  /// Payment details and payment terms — measured for pagination when totals live in the line-items grid.
  static func documentFooterBlock(
    viewModel: InvoiceEditorViewModel,
    contentWidth: CGFloat
  ) -> some View {
    documentPaymentFooter(
      viewModel: viewModel,
      contentWidth: contentWidth
    )
  }

  private static func totalsAmountGridRow(
    label: String,
    amount: Decimal,
    amountFont: Font,
    currencyCode: String,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    labelColumnSpan: Int,
    rowHeight: CGFloat,
    visibility: LineItemColumnVisibility,
    currencyDisplayStyle: InvoiceCurrencyDisplayStyle = .default,
    emphasized: Bool = false
  ) -> some View {
    GridRow {
      totalsEmptyDateCell(columnWidths: columnWidths, visibility: visibility)
      totalsEmptyDescriptionCell(width: descriptionColumnWidth)
      totalsLabelRegion(
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        emphasized: emphasized
      ) {
        totalsLabel(label)
      }
      .gridCellColumns(max(labelColumnSpan, 1))
      totalsAmountText(
        amount,
        font: amountFont,
        currencyCode: currencyCode,
        displayStyle: currencyDisplayStyle
      )
      .lineItemPreviewTotalsValueCell(
        width: columnWidths.total,
        emphasized: emphasized
      )
    }
    .frame(height: rowHeight)
  }

  private static func totalsRateValueGridRow(
    label: String,
    value: String,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    labelColumnSpan: Int,
    font: Font,
    rowHeight: CGFloat,
    visibility: LineItemColumnVisibility,
    emphasized: Bool = false
  ) -> some View {
    GridRow {
      totalsEmptyDateCell(columnWidths: columnWidths, visibility: visibility)
      totalsEmptyDescriptionCell(width: descriptionColumnWidth)
      totalsLabelRegion(
        labelColumnWidth: labelColumnWidth,
        labelRegionWidth: labelRegionWidth,
        emphasized: emphasized
      ) {
        totalsLabel(label)
      }
      .gridCellColumns(max(labelColumnSpan, 1))
      Text(value)
        .font(font)
        .monospacedDigit()
        .lineItemPreviewTotalsValueCell(
          width: columnWidths.total,
          emphasized: emphasized
        )
    }
    .frame(height: rowHeight)
  }

  private static func totalsGrandTotalGridRow(
    viewModel: InvoiceEditorViewModel,
    columnWidths: LineItemTableColumnWidths,
    descriptionColumnWidth: CGFloat,
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    rowHeight: CGFloat
  ) -> some View {
    TotalsGrandTotalGridRow(
      viewModel: viewModel,
      columnWidths: columnWidths,
      descriptionColumnWidth: descriptionColumnWidth,
      labelColumnWidth: labelColumnWidth,
      labelRegionWidth: labelRegionWidth,
      labelColumnSpan: viewModel.columnVisibility.totalsLabelColumnSpan,
      rowHeight: rowHeight
    )
  }

  @ViewBuilder
  private static func totalsEmptyDateCell(
    columnWidths: LineItemTableColumnWidths,
    visibility: LineItemColumnVisibility
  ) -> some View {
    if visibility.showDate {
      Color.clear
        .lineItemPreviewTotalsEmptyCell(
          column: .date,
          width: columnWidths.date
        )
    }
  }

  private static func totalsEmptyDescriptionCell(width: CGFloat) -> some View {
    Color.clear
      .lineItemPreviewTotalsEmptyCell(
        column: .description,
        width: width
      )
  }

  private static func totalsLabelRegion<Label: View>(
    labelColumnWidth: CGFloat,
    labelRegionWidth: CGFloat,
    emphasized: Bool = false,
    @ViewBuilder label: () -> Label
  ) -> some View {
    Color.clear
      .lineItemPreviewTotalsLabelRegionCell(
        regionWidth: labelRegionWidth,
        labelColumnWidth: labelColumnWidth,
        emphasized: emphasized,
        label: label
      )
  }

  private static func totalsLabel(_ label: String) -> some View {
    Text(label)
      .resolvedInvoiceFont(.fieldLabel)
      .foregroundStyle(InvoiceDocumentDesign.inkMuted)
      .frame(maxWidth: .infinity, alignment: InvoiceDocumentDesign.labelValueLabelAlignment)
  }

  private static func totalsAmountText(
    _ amount: Decimal,
    font: Font,
    currencyCode: String,
    displayStyle: InvoiceCurrencyDisplayStyle = .default
  ) -> some View {
    Text(
      InvoiceMoneyFormatter.string(
        for: amount, currencyCode: currencyCode, displayStyle: displayStyle)
    )
    .font(font)
    .monospacedDigit()
  }

  /// Payment Details rendered as a ruled label/value table so it reads as a
  /// tabular echo of the invoice details table in the header.
  @ViewBuilder
  private static func paymentDetailsCard(
    viewModel: InvoiceEditorViewModel,
    expandsToFillHeight: Bool = false,
    showsOutline: Bool = true,
    showsFill: Bool = true,
    showsLabels: Bool = true,
    showsRowRules: Bool = true,
    inspectorInteraction: InvoicePreviewInspectorInteraction? = nil
  ) -> some View {
    let rows: [(label: String, value: String, target: InvoiceInspectorFocusTarget)] = [
      ("Bank", viewModel.bankName, .bankName),
      ("Account", viewModel.bankAccountName, .bankAccountName),
      ("BSB", viewModel.bankBSB, .bankBSB),
      ("Acc No.", viewModel.bankAccountNumber, .bankAccountNumber),
    ]

    ThemedDocumentBandedCard(
      label: "Payment Details",
      kind: .payment,
      flushBody: true,
      showsOutline: showsOutline,
      showsFill: showsFill,
      expandsToFillHeight: expandsToFillHeight,
      inspectorHeaderTarget: .paymentDetails,
      inspectorInteraction: inspectorInteraction
    ) {
      VStack(alignment: .leading, spacing: 0) {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
          PaymentDetailRowView(
            label: row.label,
            value: row.value,
            isLast: index == rows.count - 1,
            showsLabel: showsLabels,
            showsRowRule: showsRowRules
          )
          .previewInspectorTargetIfPresent(row.target, interaction: inspectorInteraction)
        }
      }
    }
  }

  /// Payment Terms in a card matching the payment details styling so the two
  /// read as one unified footer block.
  private static func paymentTermsCard(
    terms: String,
    notes: String,
    expandsToFillHeight: Bool = false,
    showsOutline: Bool = true,
    showsFill: Bool = true
  ) -> some View {
    ThemedDocumentBandedCard(
      label: notes.isEmpty ? "Payment Terms" : "Payment Terms & Notes",
      kind: .payment,
      showsOutline: showsOutline,
      showsFill: showsFill,
      expandsToFillHeight: expandsToFillHeight
    ) {
      if terms.isEmpty, notes.isEmpty {
        Text("—")
          .resolvedInvoiceFont(.body)
          .foregroundStyle(InvoiceDocumentDesign.inkFaint)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        VStack(alignment: .leading, spacing: 6) {
          if !terms.isEmpty {
            Text(terms)
              .resolvedInvoiceFont(.body)
              .foregroundStyle(InvoiceDocumentDesign.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
          if !notes.isEmpty {
            if !terms.isEmpty { Divider() }
            Text("Notes")
              .resolvedInvoiceFont(.meta)
              .foregroundStyle(InvoiceDocumentDesign.inkMuted)
            Text(notes)
              .resolvedInvoiceFont(.body)
              .foregroundStyle(InvoiceDocumentDesign.ink)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
  }

  static func pageNumberLabel(pageIndex: Int, totalPages: Int, showsChrome: Bool = true)
    -> some View
  {
    Group {
      if showsChrome {
        Text("Page \(pageIndex + 1) of \(totalPages)")
          .font(InvoiceDocumentDesign.chromeFont)
          .foregroundStyle(InvoiceDocumentDesign.inkMuted)
          .monospacedDigit()
          .documentChromeCapsule()
      } else {
        Text("Page \(pageIndex + 1) of \(totalPages)")
          .font(InvoiceDocumentDesign.chromeFont)
          .foregroundStyle(InvoiceDocumentDesign.inkMuted)
          .monospacedDigit()
      }
    }
    .padding(.bottom, 5)
  }
}
