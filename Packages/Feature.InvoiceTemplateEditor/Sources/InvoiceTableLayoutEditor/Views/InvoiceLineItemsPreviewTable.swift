import SwiftUI

/// Read-only line-items grid for the invoice document preview.
struct InvoiceLineItemsPreviewTable: View {
    @Bindable var viewModel: InvoiceEditorViewModel
    var contentWidth: CGFloat = InvoiceLineItemsTypography.referenceContentWidth
    var lineItemIDs: [UUID]?
    var showsHeader: Bool = true
    var showsTotals: Bool = false
    /// Present only in the live document preview. Pagination measurement uses
    /// the same table without interactive regions.
    var inspectorInteraction: InvoicePreviewInspectorInteraction?

    private var typographyScale: CGFloat { viewModel.resolvedDocumentStyle.typographyScale }
    private var cellFont: Font { InvoiceDocumentDesign.bodyFont(scale: typographyScale, family: viewModel.fontFamily) }
    private var headerFont: Font { InvoiceDocumentDesign.tableHeaderFont(scale: typographyScale, family: viewModel.fontFamily) }
    private var captionFont: Font { InvoiceDocumentDesign.metaFont(scale: typographyScale, family: viewModel.fontFamily) }

    private var visibility: LineItemColumnVisibility { viewModel.columnVisibility }

    private var displayedLineItems: [InvoiceLineItemSnapshot] {
        guard let lineItemIDs else { return viewModel.lineItems }
        let lookup = Dictionary(
            viewModel.lineItems.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return lineItemIDs.compactMap { lookup[$0] }
    }

    /// Items not on this page still participate in column sizing so widths stay
    /// consistent across paginated slices and match the totals section measurer.
    private var sizingOnlyLineItems: [InvoiceLineItemSnapshot] {
        let displayedIDs = Set(displayedLineItems.map(\.id))
        return viewModel.lineItems.filter { !displayedIDs.contains($0.id) }
    }

    private var totalsSnapshot: LineItemTableTotalsSnapshot {
        let discountValue = InvoiceCalculations.discountValue(
            subtotal: viewModel.liveTotals.subtotal,
            discountAmount: viewModel.discountAmount,
            discountPercent: viewModel.discountPercent
        )
        return LineItemTableTotalsSnapshot(
            subtotal: viewModel.liveTotals.subtotal,
            discountPercent: viewModel.discountPercent,
            discountValue: discountValue,
            taxTotal: viewModel.liveTotals.taxTotal,
            creditApplied: viewModel.creditApplied,
            grandTotal: viewModel.liveTotals.grandTotal
        )
    }

    /// Measured widths for shrink-to-fit columns; Description flexes in the remainder.
    private var columnWidths: LineItemTableColumnWidths {
        let measured = LineItemColumnWidthMeasurer.measure(
            lineItems: viewModel.lineItems,
            presentation: .preview,
            totals: totalsSnapshot,
            density: viewModel.typographyDensity,
            typographyScale: typographyScale,
            currencyCode: viewModel.currencyCode,
            currencyDisplayStyle: viewModel.currencyDisplayStyle,
            showsItemCode: visibility.showItemCode
                ? { !$0.itemCode.isEmpty }
                : { _ in false }
        )
        return adjustedWidths(measured)
    }

    private func adjustedWidths(_ widths: LineItemTableColumnWidths) -> LineItemTableColumnWidths {
        LineItemTableColumnWidths(
            date: visibility.showDate ? widths.date : 0,
            description: widths.description,
            qty: visibility.showQty ? widths.qty : 0,
            unit: visibility.showUnit ? widths.unit : 0,
            rate: visibility.showRate ? widths.rate : 0,
            total: widths.total
        )
    }

    private var headerRowHeight: CGFloat {
        LineItemRowHeightMeasurer.tableHeaderHeight(
            presentation: .preview,
            density: viewModel.typographyDensity,
            typographyScale: typographyScale
        )
    }

    private func dataRowHeight(for item: InvoiceLineItemSnapshot) -> CGFloat {
        LineItemRowHeightMeasurer.height(
            for: item,
            presentation: .preview,
            includesItemCode: visibility.showItemCode,
            density: viewModel.typographyDensity,
            typographyScale: typographyScale
        )
    }

    private var totalsRowHeight: CGFloat {
        let base = LineItemRowHeightMeasurer.previewDataRowHeight(
            includesItemCode: false,
            density: viewModel.typographyDensity,
            typographyScale: typographyScale
        )
        return (base * viewModel.totalsEmphasis.rowHeightScale).rounded(.toNearestOrAwayFromZero)
    }

    private var estimatedTableHeight: CGFloat {
        let lineItemsHeight = LineItemRowHeightMeasurer.tableHeight(
            for: displayedLineItems,
            showsHeader: showsHeader,
            presentation: .preview,
            density: viewModel.typographyDensity,
            typographyScale: typographyScale
        )
        guard showsTotals else { return lineItemsHeight }

        let discountValue = InvoiceCalculations.discountValue(
            subtotal: viewModel.liveTotals.subtotal,
            discountAmount: viewModel.discountAmount,
            discountPercent: viewModel.discountPercent
        )
        let totalsHeight = LineItemRowHeightMeasurer.totalsGridHeight(
            discountPercent: viewModel.discountPercent,
            discountValue: discountValue,
            taxTotal: viewModel.liveTotals.taxTotal,
            creditApplied: viewModel.creditApplied,
            showsTaxSummary: viewModel.showsTaxSummary,
            density: viewModel.typographyDensity,
            typographyScale: typographyScale
        ) * viewModel.totalsEmphasis.rowHeightScale
        return lineItemsHeight + totalsHeight
    }

    var body: some View {
        let widths = columnWidths
        let descriptionWidth = widths.descriptionColumnWidth(for: contentWidth)

        return Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
            if showsHeader {
                GridRow {
                    if visibility.showDate {
                        headerText(LineItemTableColumn.date.headerTitle)
                            .lineItemPreviewGridCell(column: .date, isHeader: true, width: widths.date)
                    }
                    headerText(LineItemTableColumn.description.headerTitle)
                        .lineItemPreviewGridCell(column: .description, isHeader: true, width: descriptionWidth)
                    if visibility.showQty {
                        centeredHeaderText(LineItemTableColumn.qty.headerTitle, column: .qty, width: widths.qty)
                    }
                    if visibility.showUnit {
                        centeredHeaderText(LineItemTableColumn.unit.headerTitle, column: .unit, width: widths.unit)
                    }
                    if visibility.showRate {
                        trailingHeaderText(LineItemTableColumn.rate.headerTitle, column: .rate, width: widths.rate)
                    }
                    trailingHeaderText(LineItemTableColumn.total.headerTitle, column: .total, width: widths.total)
                }
                .frame(height: headerRowHeight)
                .previewInspectorTargetIfPresent(.lineItems, interaction: inspectorInteraction)
            }

            ForEach(Array(displayedLineItems.enumerated()), id: \.element.id) { index, item in
                lineItemRow(for: item, rowIndex: index)
                    .frame(height: dataRowHeight(for: item))
            }

            if showsTotals {
                InvoiceDocumentSections.totalsGridRows(
                    viewModel: viewModel,
                    columnWidths: widths,
                    descriptionColumnWidth: descriptionWidth,
                    rowHeight: totalsRowHeight,
                    inspectorInteraction: inspectorInteraction
                )
            }

            ForEach(sizingOnlyLineItems) { item in
                lineItemRow(for: item)
                    .frame(maxHeight: 0)
                    .clipped()
                    .accessibilityHidden(true)
            }
        }
        .font(cellFont)
        .frame(width: contentWidth, height: estimatedTableHeight, alignment: .topLeading)
    }

    @ViewBuilder
    private func lineItemRow(for item: InvoiceLineItemSnapshot, rowIndex: Int = 0) -> some View {
        let widths = columnWidths
        let descriptionWidth = widths.descriptionColumnWidth(for: contentWidth)
        let zebra = rowIndex.isMultiple(of: 2)

        GridRow {
            if visibility.showDate {
                Text(InvoiceDateFormatter.documentString(for: item.serviceDate, style: viewModel.dateFormatStyle))
                    .font(cellFont)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .lineItemPreviewGridCell(column: .date, width: widths.date, zebra: zebra)
                    .previewInspectorTargetIfPresent(.lineItemServiceDate(item.id), interaction: inspectorInteraction)
            }

            descriptionCell(for: item)
                .lineItemPreviewGridCell(column: .description, width: descriptionWidth, zebra: zebra)

            if visibility.showQty {
                centeredCell(column: .qty, width: widths.qty, zebra: zebra) {
                    Text(InvoiceDecimalFormatter.string(for: item.quantity))
                        .font(cellFont)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .previewInspectorTargetIfPresent(.lineItemQuantity(item.id), interaction: inspectorInteraction)
            }

            if visibility.showUnit {
                centeredCell(column: .unit, width: widths.unit, zebra: zebra) {
                    Text(item.unit)
                        .font(cellFont)
                        .lineLimit(1)
                }
                .previewInspectorTargetIfPresent(.lineItemUnit(item.id), interaction: inspectorInteraction)
            }

            if visibility.showRate {
                trailingCell(column: .rate, width: widths.rate, zebra: zebra) {
                    Text(InvoiceMoneyFormatter.string(
                        for: item.unitPrice,
                        currencyCode: viewModel.currencyCode,
                        displayStyle: viewModel.currencyDisplayStyle
                    ))
                        .font(cellFont)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .previewInspectorTargetIfPresent(.lineItemUnitPrice(item.id), interaction: inspectorInteraction)
            }

            trailingCell(column: .total, width: widths.total, zebra: zebra) {
                Text(InvoiceMoneyFormatter.string(
                    for: item.lineTotal,
                    currencyCode: viewModel.currencyCode,
                    displayStyle: viewModel.currencyDisplayStyle
                ))
                    .font(cellFont)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .previewInspectorTargetIfPresent(.lineItemTaxRate(item.id), interaction: inspectorInteraction)
        }
    }

    private func headerText(_ title: String) -> some View {
        ThemedAccentMutedText(
            title: title,
            font: headerFont,
            tracking: InvoiceLineItemsTableStyle.headerTracking,
            emphasized: true
        )
    }

    private func trailingHeaderText(
        _ title: String,
        column: LineItemTableColumn,
        width: CGFloat
    ) -> some View {
        trailingCell(column: column, isHeader: true, width: width) {
            ThemedAccentMutedText(
                title: title,
                font: headerFont,
                tracking: InvoiceLineItemsTableStyle.headerTracking,
                emphasized: true
            )
        }
    }

    private func centeredHeaderText(
        _ title: String,
        column: LineItemTableColumn,
        width: CGFloat
    ) -> some View {
        centeredCell(column: column, isHeader: true, width: width) {
            ThemedAccentMutedText(
                title: title,
                font: headerFont,
                tracking: InvoiceLineItemsTableStyle.headerTracking,
                emphasized: true
            )
        }
    }

    @ViewBuilder
    private func centeredCell<Content: View>(
        column: LineItemTableColumn,
        isHeader: Bool = false,
        width: CGFloat,
        zebra: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .lineItemPreviewGridCell(
                column: column,
                isHeader: isHeader,
                alignment: .center,
                width: width,
                zebra: zebra
            )
    }

    @ViewBuilder
    private func trailingCell<Content: View>(
        column: LineItemTableColumn,
        isHeader: Bool = false,
        width: CGFloat,
        zebra: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .lineItemPreviewGridCell(
                column: column,
                isHeader: isHeader,
                alignment: .trailing,
                width: width,
                zebra: zebra
            )
    }

    private func descriptionCell(for item: InvoiceLineItemSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(item.itemDescription)
                .font(cellFont)
                .lineLimit(viewModel.showServiceDatesInDescription ? 2 : 1)
                .previewInspectorTargetIfPresent(.lineItemDescription(item.id), interaction: inspectorInteraction)

            if viewModel.showServiceDatesInDescription {
                Text(InvoiceDateFormatter.documentString(for: item.serviceDate, style: viewModel.dateFormatStyle))
                    .font(captionFont)
                    .foregroundStyle(InvoiceDocumentDesign.inkMuted)
                    .lineLimit(1)
            }

            if visibility.showItemCode {
                Text(item.itemCode.isEmpty ? "—" : item.itemCode)
                    .font(captionFont)
                    .foregroundStyle(item.itemCode.isEmpty ? InvoiceDocumentDesign.inkFaint : InvoiceDocumentDesign.inkMuted)
                    .lineLimit(1)
                    .previewInspectorTargetIfPresent(.lineItemCode(item.id), interaction: inspectorInteraction)
            }
        }
    }
}

private struct ThemedAccentMutedText: View {
    @Environment(\.invoiceTheme) private var theme

    let title: String
    let font: Font
    var tracking: CGFloat = 0
    /// When true, use full accent (stronger than muted) for column headers.
    var emphasized: Bool = false

    var body: some View {
        Text(title)
            .font(font)
            .tracking(tracking)
            .foregroundStyle(emphasized ? theme.accent : theme.accentMuted)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }
}
