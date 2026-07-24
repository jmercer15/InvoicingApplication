import AppKit
import Core
import CoreGraphics
import Foundation

/// Identifiers for the six invoice line-item table columns.
enum LineItemTableColumn: Int, CaseIterable, Hashable {
    case date
    case description
    case qty
    case unit
    case rate
    case total

    var headerTitle: String {
        switch self {
        case .date: "Service Date"
        case .description: "Description"
        case .qty: "Qty"
        case .unit: "Unit"
        case .rate: "Unit Price"
        case .total: "Total"
        }
    }
}

/// Measured minimum widths for each line-item column (content-hugging columns).
struct LineItemTableColumnWidths: Equatable {
    let date: CGFloat
    let description: CGFloat
    let qty: CGFloat
    let unit: CGFloat
    let rate: CGFloat
    let total: CGFloat

    subscript(column: LineItemTableColumn) -> CGFloat {
        switch column {
        case .date: date
        case .description: description
        case .qty: qty
        case .unit: unit
        case .rate: rate
        case .total: total
        }
    }

    /// Width spanned by description, qty, and unit columns in the totals section.
    var descriptionBlockWidth: CGFloat {
        description + qty + unit
    }

    /// Width spanned by the qty and unit columns (totals label column).
    var qtyUnitWidth: CGFloat {
        qty + unit
    }

    /// Width spanned by the qty, unit, and rate columns (totals label region).
    var qtyUnitRateWidth: CGFloat {
        qty + unit + rate
    }

    /// Width spanned by the rate and total columns (totals value column).
    var rateTotalWidth: CGFloat {
        rate + total
    }

    /// Sum of the five fixed-width columns (everything except description flex).
    var fixedColumnsWidth: CGFloat {
        date + qty + unit + rate + total
    }

    /// Description column width that fills the printable content area.
    func descriptionColumnWidth(for contentWidth: CGFloat) -> CGFloat {
        max(contentWidth - fixedColumnsWidth, description)
    }
}

/// Whether line-item table measurements include editable control chrome.
enum LineItemTablePresentation {
    case preview
    case editable
}

/// Totals-section amounts shown in the preview grid's Total column.
struct LineItemTableTotalsSnapshot: Equatable {
    var subtotal: Decimal = 0
    var discountPercent: Decimal = 0
    var discountValue: Decimal = 0
    var taxTotal: Decimal = 0
    var creditApplied: Decimal = 0
    var grandTotal: Decimal = 0
}

/// Computes per-column minimum widths from header and cell text at fixed document font sizes.
///
/// Widths are text measurements plus minimal control chrome only. macOS `Table` applies its
/// own cell insets, so table-level horizontal padding is not added here.
///
/// Control chrome is applied to cell content only — never to header text. Headers share the
/// column with cells, so each width is `max(header, cellContent)`.
enum LineItemColumnWidthMeasurer {
    // MARK: Document table chrome (editable `Table` cells; Table already adds cell insets)

    /// Trailing calendar affordance on a compact `DatePicker` (not full control width).
    static let datePickerChrome: CGFloat = 14
    /// Combined horizontal inset for a bordered numeric `TextField` in the document table.
    static let numericFieldChrome: CGFloat = 6
    /// Spacing between an editable currency / percentage affix and its value.
    static let numericAffixSpacing: CGFloat = 2
    /// Compatibility aliases for existing width-measurement tests.
    static let decimalFieldChrome = numericFieldChrome
    static let decimalAffixSpacing = numericAffixSpacing

    // MARK: Inspector Form chrome (measured against AppKit / SwiftUI control footprints)

    /// Horizontal bezel inset for a `.roundedBorder` `TextField` in the inspector.
    /// Matches `InspectorControlMetrics.roundedBorderChrome` (measured AppKit cellSize − text).
    static let textFieldChrome: CGFloat = InspectorControlMetrics.roundedBorderChrome

    /// Fitting width of a compact inspector `DatePicker` (measured hosted control).
    static let inspectorCompactDatePickerWidth: CGFloat =
        InspectorControlMetrics.compactDatePickerSize.width

    /// Fitting height of a compact inspector `DatePicker` (measured hosted control).
    static let inspectorCompactDatePickerHeight: CGFloat =
        InspectorControlMetrics.compactDatePickerSize.height

    static func measure(
        lineItems: [InvoiceLineItemSnapshot],
        presentation: LineItemTablePresentation = .preview,
        totals: LineItemTableTotalsSnapshot? = nil,
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil,
        currencyCode: String = InvoiceCurrencyCode.defaultValue,
        currencyDisplayStyle: InvoiceCurrencyDisplayStyle = .default,
        showsItemCode: (InvoiceLineItemSnapshot) -> Bool = { !$0.itemCode.isEmpty }
    ) -> LineItemTableColumnWidths {
        let dateChrome = presentation == .editable ? datePickerChrome : 0
        let numericChrome = presentation == .editable ? numericFieldChrome : 0
        let cellHorizontalInset = presentation == .preview
            ? InvoiceLineItemsTableStyle.cellHorizontalInset
            : 0
        let resolvedScale = typographyScale ?? density.scale
        let bodySize = InvoiceLineItemsTypography.bodyFontSize(scale: resolvedScale)
        let metaSize = InvoiceLineItemsTypography.metaFontSize(scale: resolvedScale)
        let cellFont = NSFont.systemFont(ofSize: bodySize)
        let headerFont = presentation == .preview
            ? NSFont.systemFont(ofSize: bodySize, weight: .bold)
            : NSFont.boldSystemFont(ofSize: bodySize)
        let headerTracking = presentation == .preview
            ? InvoiceLineItemsTableStyle.headerTracking
            : 0
        let captionFont = NSFont.systemFont(ofSize: metaSize)
        // Preview numeric cells use SwiftUI `.monospacedDigit()`; editable cells do not.
        let numericCellFont = presentation == .preview
            ? NSFont.monospacedDigitSystemFont(ofSize: bodySize, weight: .regular)
            : cellFont

        let dateHeader = textWidth(LineItemTableColumn.date.headerTitle, font: headerFont, tracking: headerTracking)
        let descriptionHeader = textWidth(LineItemTableColumn.description.headerTitle, font: headerFont, tracking: headerTracking)
        let qtyHeader = textWidth(LineItemTableColumn.qty.headerTitle, font: headerFont, tracking: headerTracking)
        let unitHeader = textWidth(LineItemTableColumn.unit.headerTitle, font: headerFont, tracking: headerTracking)
        let rateHeader = textWidth(LineItemTableColumn.rate.headerTitle, font: headerFont, tracking: headerTracking)
        let totalHeader = textWidth(LineItemTableColumn.total.headerTitle, font: headerFont, tracking: headerTracking)

        var dateCell = CGFloat.zero
        var descriptionCell = CGFloat.zero
        var qtyCell = CGFloat.zero
        var unitCell = CGFloat.zero
        var rateCell = CGFloat.zero
        var totalCell = CGFloat.zero

        let moneyAffixWidth = editableMoneyAffixWidth(
            currencyCode: currencyCode,
            displayStyle: currencyDisplayStyle,
            font: cellFont
        )

        for item in lineItems {
            let dateText = InvoiceDateFormatter.compactString(for: item.serviceDate)
            dateCell = max(
                dateCell,
                textWidth(dateText, font: cellFont) + dateChrome
            )

            if !item.itemDescription.isEmpty {
                descriptionCell = max(
                    descriptionCell,
                    textWidth(item.itemDescription, font: cellFont)
                )
            }
            if presentation == .preview || showsItemCode(item) {
                let codeText = item.itemCode.isEmpty ? "—" : item.itemCode
                descriptionCell = max(descriptionCell, textWidth(codeText, font: captionFont))
            }

            let qtyText = InvoiceDecimalFormatter.string(for: item.quantity)
            qtyCell = max(qtyCell, textWidth(qtyText, font: numericCellFont) + numericChrome)

            if !item.unit.isEmpty {
                unitCell = max(unitCell, textWidth(item.unit, font: cellFont))
            }

            let rateAffix = presentation == .editable ? moneyAffixWidth : 0
            let rateText = presentation == .editable
                ? InvoiceMoneyFormatter.editableString(for: item.unitPrice)
                : InvoiceMoneyFormatter.string(
                    for: item.unitPrice,
                    currencyCode: currencyCode,
                    displayStyle: currencyDisplayStyle
                )
            rateCell = max(
                rateCell,
                textWidth(rateText, font: numericCellFont) + numericChrome + rateAffix
            )

            let totalText = InvoiceMoneyFormatter.string(
                for: item.lineTotal,
                currencyCode: currencyCode,
                displayStyle: currencyDisplayStyle
            )
            totalCell = max(totalCell, textWidth(totalText, font: numericCellFont))
        }

        if presentation == .preview, let totals {
            totalCell = max(
                totalCell,
                measureTotalsValueColumnWidth(
                    totals: totals,
                    numericCellFont: numericCellFont,
                    currencyCode: currencyCode,
                    currencyDisplayStyle: currencyDisplayStyle
                )
            )
        }

        return LineItemTableColumnWidths(
            date: max(dateHeader, dateCell) + cellHorizontalInset,
            description: max(descriptionHeader, descriptionCell) + cellHorizontalInset,
            qty: max(qtyHeader, qtyCell) + cellHorizontalInset,
            unit: max(unitHeader, unitCell) + cellHorizontalInset,
            rate: max(rateHeader, rateCell) + cellHorizontalInset,
            total: max(totalHeader, totalCell) + cellHorizontalInset
        )
    }

    /// Widest totals-row label width at document fonts, plus preview cell padding.
    ///
    /// Regular labels use the caption field-label font; the grand-total label
    /// ("Total Payable") is measured at body emphasis weight in case it is wider.
    static func measureTotalsLabelWidth(
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil
    ) -> CGFloat {
        let bodySize = InvoiceLineItemsTypography.bodyFontSize(scale: typographyScale ?? density.scale)
        let metaSize = InvoiceLineItemsTypography.metaFontSize(for: density)
        let captionFont = NSFont.systemFont(ofSize: metaSize, weight: .medium)
        let emphasisFont = NSFont.systemFont(ofSize: bodySize, weight: .semibold)
        let cellHorizontalInset = InvoiceLineItemsTableStyle.cellHorizontalInset

        let regularLabels = [
            "Subtotal",
            "Disc %",
            "Discount",
            "Tax",
            "GST",
            "VAT",
            "Credit",
            "Tax exempt",
            "GST-free",
            "VAT exempt",
        ]

        var maxTextWidth = textWidth("Total Payable", font: emphasisFont)
        for label in regularLabels {
            maxTextWidth = max(maxTextWidth, textWidth(label, font: captionFont))
        }

        return maxTextWidth + cellHorizontalInset
    }

    /// Widest totals-section value rendered in the Total column at document fonts.
    static func measureTotalsValueColumnWidth(
        totals: LineItemTableTotalsSnapshot,
        numericCellFont: NSFont,
        density: InvoiceTypographyDensity = .default,
        taxLabelStyle: InvoiceTaxLabelStyle = .default,
        currencyCode: String = InvoiceCurrencyCode.defaultValue,
        currencyDisplayStyle: InvoiceCurrencyDisplayStyle = .default
    ) -> CGFloat {
        let bodySize = InvoiceLineItemsTypography.bodyFontSize(for: density)
        let boldNumericCellFont = NSFont.monospacedDigitSystemFont(ofSize: bodySize, weight: .bold)
        let money: (Decimal) -> String = { amount in
            InvoiceMoneyFormatter.string(
                for: amount,
                currencyCode: currencyCode,
                displayStyle: currencyDisplayStyle
            )
        }

        var maxWidth = textWidth(money(totals.subtotal), font: numericCellFont)

        if totals.discountPercent != 0 {
            let percentText = "\(InvoiceDecimalFormatter.string(for: totals.discountPercent))%"
            maxWidth = max(maxWidth, textWidth(percentText, font: numericCellFont))
        }

        if totals.discountValue != 0 {
            maxWidth = max(maxWidth, textWidth(money(totals.discountValue), font: numericCellFont))
        }

        if totals.taxTotal != 0 {
            maxWidth = max(maxWidth, textWidth(money(totals.taxTotal), font: numericCellFont))
        } else {
            maxWidth = max(maxWidth, textWidth(taxLabelStyle.zeroTaxLabel, font: numericCellFont))
        }

        if totals.creditApplied != 0 {
            maxWidth = max(maxWidth, textWidth(money(totals.creditApplied), font: numericCellFont))
        }

        let grandTotalText = money(totals.grandTotal)
        maxWidth = max(
            maxWidth,
            textWidth(grandTotalText, font: numericCellFont),
            textWidth(grandTotalText, font: boldNumericCellFont)
        )

        return maxWidth
    }

    private static func editableMoneyAffixWidth(
        currencyCode: String,
        displayStyle: InvoiceCurrencyDisplayStyle,
        font: NSFont
    ) -> CGFloat {
        let affixes = [
            InvoiceMoneyFormatter.editablePrefix(
                currencyCode: currencyCode,
                displayStyle: displayStyle
            ),
            InvoiceMoneyFormatter.editableSuffix(
                currencyCode: currencyCode,
                displayStyle: displayStyle
            ),
        ].compactMap { $0 }

        return affixes.reduce(CGFloat.zero) { width, affix in
            width + textWidth(affix, font: font) + numericAffixSpacing
        }
    }

    private static func textWidth(_ string: String, font: NSFont, tracking: CGFloat = 0) -> CGFloat {
        let base = (string as NSString).size(withAttributes: [.font: font]).width
        let kernExtra: CGFloat
        if tracking != 0, string.count > 1 {
            kernExtra = tracking * CGFloat(string.count - 1)
        } else {
            kernExtra = 0
        }
        return ceil(base + kernExtra)
    }
}

// MARK: - Inspector control footprints (empirically measured)

/// Footprints for inspector Form controls, taken from hosted SwiftUI / AppKit probes.
///
/// Live `NSHostingView` / `NSTextField` probing is MainActor-isolated under Swift 6 and
/// cannot run from pagination helpers, so these cache the measured values. Re-verify on
/// major OS releases if compact `DatePicker` or rounded-bezel metrics change.
enum InspectorControlMetrics {
    /// Compact `DatePicker` fitting size (`NSHostingView` + `.datePickerStyle(.compact)`).
    /// Width is stable across dates for a given locale; height is font-independent.
    static let compactDatePickerSize = CGSize(width: 95, height: 22)

    /// Horizontal chrome of `.roundedBorder` / rounded-bezel fields
    /// (`NSTextField.cellSize.width − string width`, consistently 12 across 11–15pt).
    static let roundedBorderChrome: CGFloat = 12

    /// Rounded-border field height at `NSFont.systemFontSize` (13pt).
    static let systemRoundedBorderFieldHeight: CGFloat = 24

    /// Width of a rounded-border field showing `string` at `font`.
    static func roundedBorderFieldWidth(for string: String, font: NSFont) -> CGFloat {
        let stringWidth = ceil(
            (string as NSString).size(withAttributes: [.font: font]).width
        )
        return stringWidth + roundedBorderChrome
    }

    /// Height of a rounded-border field at `font` (plain line + bezel inset).
    static func roundedBorderFieldHeight(font: NSFont) -> CGFloat {
        if font.pointSize == NSFont.systemFontSize {
            return systemRoundedBorderFieldHeight
        }
        let plain = max(
            ceil(font.ascender - font.descender),
            ceil(font.boundingRectForFont.height)
        )
        return plain + LineItemRowHeightMeasurer.roundedBorderFieldBezelInset
    }
}

/// Shared column widths for the inspector line-item header and value rows.
/// Estimates rendered row height for pagination.
///
/// Preview `Grid` rows include cell padding from `InvoiceLineItemsTableStyle`; borders
/// are drawn as 1pt overlays and do not affect layout height. Editable
/// `Table` rows follow the tallest cell control (compact `DatePicker`, bordered
/// a numeric `TextField`, or description `TextField` stack), plus macOS `Table` cell insets;
/// `tableHeight` also includes 1pt grid lines from `.bordered` table style.
enum LineItemRowHeightMeasurer {
    /// Top + bottom inset macOS `Table` applies around cell content.
    static let rowVerticalPadding: CGFloat = 10
    static let interLineSpacing: CGFloat = 1
    /// Extra vertical chrome for the column-header row in a macOS `Table`.
    static let tableHeaderVerticalPadding: CGFloat = 12
    /// Horizontal grid line between `.bordered` `Table` rows (not part of row content).
    static let borderedTableRowSeparatorHeight: CGFloat = 1
    /// Compact SwiftUI `DatePicker` intrinsic height (measured; font-independent).
    static let compactDatePickerHeight: CGFloat =
        InspectorControlMetrics.compactDatePickerSize.height
    /// Extra height `NSTextField` rounded bezel adds beyond plain text at the reference size.
    static let roundedBorderFieldBezelInset: CGFloat = 8

    static func hasItemCode(for item: InvoiceLineItemSnapshot) -> Bool {
        !item.itemCode.isEmpty
    }

    static func tableHeaderHeight(
        presentation: LineItemTablePresentation = .preview,
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil
    ) -> CGFloat {
        let fontSize = InvoiceLineItemsTypography.bodyFontSize(scale: typographyScale ?? density.scale)
        switch presentation {
        case .preview:
            return textLineHeight(fontSize: fontSize, weight: .bold)
                + InvoiceLineItemsTableStyle.headerCellVerticalInset
        case .editable:
            let textHeight = headerTextHeight(fontSize: fontSize)
            return textHeight + tableHeaderVerticalPadding
        }
    }

    /// Total height for a line-items slice (optional header plus body rows).
    static func tableHeight(
        for items: [InvoiceLineItemSnapshot],
        showsHeader: Bool,
        presentation: LineItemTablePresentation = .preview,
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil,
        showsItemCode: (InvoiceLineItemSnapshot) -> Bool = { !$0.itemCode.isEmpty }
    ) -> CGFloat {
        let headerPart = showsHeader
            ? tableHeaderHeight(presentation: presentation, density: density, typographyScale: typographyScale)
            : 0
        let dataHeight = items.reduce(CGFloat.zero) { total, item in
            let includesCode = presentation == .preview ? true : showsItemCode(item)
            return total + height(
                for: item,
                presentation: presentation,
                includesItemCode: includesCode,
                density: density,
                typographyScale: typographyScale
            )
        }
        let separatorHeight: CGFloat
        switch presentation {
        case .preview:
            separatorHeight = 0
        case .editable:
            let rowCount = items.count + (showsHeader ? 1 : 0)
            separatorHeight = CGFloat(max(0, rowCount - 1)) * borderedTableRowSeparatorHeight
        }
        return headerPart + dataHeight + separatorHeight
    }

    static func previewDataRowHeight(
        includesItemCode: Bool = true,
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil
    ) -> CGFloat {
        let content = dataRowContentHeight(
            fontSize: InvoiceLineItemsTypography.bodyFontSize(scale: typographyScale ?? density.scale),
            captionSize: InvoiceLineItemsTypography.metaFontSize(scale: typographyScale ?? density.scale),
            includesItemCode: includesItemCode,
            presentation: .preview
        )
        return content + InvoiceLineItemsTableStyle.cellVerticalInset
    }

    /// Number of totals rows rendered at the bottom of the unified line-items grid.
    static func totalsRowCount(
        discountPercent: Decimal,
        discountValue: Decimal,
        taxTotal _: Decimal,
        creditApplied: Decimal,
        showsTaxSummary: Bool = true
    ) -> Int {
        var count = 2 // Subtotal, Total Payable
        if showsTaxSummary { count += 1 }
        if discountPercent != 0 { count += 1 }
        if discountValue != 0 { count += 1 }
        if creditApplied != 0 { count += 1 }
        return count
    }

    /// Estimated height for totals rows appended inside the line-items preview grid.
    static func totalsGridHeight(
        discountPercent: Decimal,
        discountValue: Decimal,
        taxTotal: Decimal,
        creditApplied: Decimal,
        showsTaxSummary: Bool = true,
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil,
        showsItemCode: Bool = false
    ) -> CGFloat {
        CGFloat(totalsRowCount(
            discountPercent: discountPercent,
            discountValue: discountValue,
            taxTotal: taxTotal,
            creditApplied: creditApplied,
            showsTaxSummary: showsTaxSummary
        )) * previewDataRowHeight(includesItemCode: showsItemCode, density: density, typographyScale: typographyScale)
    }

    static func height(
        for item: InvoiceLineItemSnapshot,
        presentation: LineItemTablePresentation = .preview,
        includesItemCode: Bool? = nil,
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil
    ) -> CGFloat {
        let showsCode = includesItemCode ?? (presentation == .preview || hasItemCode(for: item))
        let resolvedScale = typographyScale ?? density.scale
        let fontSize = InvoiceLineItemsTypography.bodyFontSize(scale: resolvedScale)
        let captionSize = InvoiceLineItemsTypography.metaFontSize(scale: resolvedScale)
        let contentHeight = dataRowContentHeight(
            fontSize: fontSize,
            captionSize: captionSize,
            includesItemCode: showsCode,
            presentation: presentation
        )
        switch presentation {
        case .preview:
            return contentHeight + InvoiceLineItemsTableStyle.cellVerticalInset
        case .editable:
            return contentHeight + rowVerticalPadding
        }
    }

    static func heights(
        for lineItems: [InvoiceLineItemSnapshot],
        presentation: LineItemTablePresentation = .preview,
        density: InvoiceTypographyDensity = .default,
        typographyScale: CGFloat? = nil,
        showsItemCode: Bool = true
    ) -> [UUID: CGFloat] {
        Dictionary(
            lineItems.map { item in
                (
                    item.id,
                    height(
                        for: item,
                        presentation: presentation,
                        includesItemCode: showsItemCode && hasItemCode(for: item),
                        density: density,
                        typographyScale: typographyScale
                    )
                )
            },
            uniquingKeysWith: { first, _ in first }
        )
    }

    /// Matches plain `TextField` intrinsic height in description / unit cells.
    static func plainTextFieldHeight(fontSize: CGFloat) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize)
        return max(
            ceil(font.ascender - font.descender),
            ceil(font.boundingRectForFont.height)
        )
    }

    /// Matches a numeric rounded-border `TextField` at the active font size.
    static func roundedBorderTextFieldHeight(fontSize: CGFloat) -> CGFloat {
        plainTextFieldHeight(fontSize: fontSize) + roundedBorderFieldBezelInset
    }

    static func dataRowContentHeight(
        fontSize: CGFloat,
        captionSize: CGFloat,
        includesItemCode: Bool,
        presentation: LineItemTablePresentation = .preview
    ) -> CGFloat {
        let descriptionHeight = descriptionStackHeight(
            fontSize: fontSize,
            captionSize: captionSize,
            includesItemCode: includesItemCode,
            presentation: presentation
        )

        switch presentation {
        case .preview:
            return descriptionHeight
        case .editable:
            return max(
                compactDatePickerHeight,
                roundedBorderTextFieldHeight(fontSize: fontSize),
                descriptionHeight
            )
        }
    }

    /// SwiftUI `Text` line height at a fixed point size (preview grid cells).
    static func textLineHeight(fontSize: CGFloat, weight: NSFont.Weight = .regular) -> CGFloat {
        let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
        return ceil(font.ascender - font.descender + font.leading)
    }

    private static func descriptionStackHeight(
        fontSize: CGFloat,
        captionSize: CGFloat,
        includesItemCode: Bool,
        presentation: LineItemTablePresentation
    ) -> CGFloat {
        switch presentation {
        case .preview:
            if includesItemCode {
                return textLineHeight(fontSize: fontSize)
                    + interLineSpacing
                    + textLineHeight(fontSize: captionSize)
            }
            return textLineHeight(fontSize: fontSize)
        case .editable:
            if includesItemCode {
                return plainTextFieldHeight(fontSize: fontSize)
                    + interLineSpacing
                    + plainTextFieldHeight(fontSize: captionSize)
            }
            return plainTextFieldHeight(fontSize: fontSize)
        }
    }

    private static func headerTextHeight(fontSize: CGFloat) -> CGFloat {
        let font = NSFont.boldSystemFont(ofSize: fontSize)
        return ceil(font.boundingRectForFont.height)
    }
}

// MARK: - NSFont mirrors (keep measurers in sync with `InvoiceDocumentDesign`)

extension InvoiceLineItemsTypography {
    static var previewBodyNSFont: NSFont {
        NSFont.systemFont(ofSize: bodyFontSize)
    }

    static var previewBodyEmphasisNSFont: NSFont {
        NSFont.systemFont(ofSize: bodyFontSize, weight: .semibold)
    }

    static var previewTableHeaderNSFont: NSFont {
        NSFont.systemFont(ofSize: bodyFontSize, weight: .bold)
    }

    static var previewBodyStrongNSFont: NSFont {
        NSFont.boldSystemFont(ofSize: bodyFontSize)
    }

    static var previewMetaNSFont: NSFont {
        NSFont.systemFont(ofSize: metaFontSize)
    }

    static var previewMetaLabelNSFont: NSFont {
        NSFont.systemFont(ofSize: metaFontSize, weight: .medium)
    }

    static var previewBodyMonospacedNSFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: bodyFontSize, weight: .regular)
    }

    static var previewBodyStrongMonospacedNSFont: NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: bodyFontSize, weight: .bold)
    }
}
