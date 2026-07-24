import CoreGraphics
import Foundation

/// Describes which invoice sections appear on a single printable page.
struct InvoicePageContent: Equatable {
    let pageIndex: Int
    let totalPages: Int
    let showsDocumentHeader: Bool
    let showsLineItemsSectionTitle: Bool
    let lineItemIDs: [UUID]
    let showsTableHeader: Bool
    let showsTotals: Bool
    let showsFooter: Bool
}

/// Pure layout engine that splits invoice content across printable pages.
enum InvoicePagination {
    struct LayoutInput {
        let lineItems: [InvoiceLineItemSnapshot]
        let paperSize: PaperSize
        let pageOrientation: PageOrientation
        let marginPoints: CGFloat
        let showPageNumbers: Bool

        init(
            lineItems: [InvoiceLineItemSnapshot],
            paperSize: PaperSize,
            pageOrientation: PageOrientation,
            marginPoints: CGFloat,
            showPageNumbers: Bool = true
        ) {
            self.lineItems = lineItems
            self.paperSize = paperSize
            self.pageOrientation = pageOrientation
            self.marginPoints = marginPoints
            self.showPageNumbers = showPageNumbers
        }
    }

    /// Measured section heights collected from a layout pass at document `contentWidth`.
    struct MeasuredDimensions: Equatable {
        let printableHeight: CGFloat
        let contentWidth: CGFloat
        let sectionSpacing: CGFloat
        let lineItemsTitleSpacing: CGFloat
        let lineItemsTopPadding: CGFloat
        let pageNumberLabelHeight: CGFloat

        let documentHeaderHeight: CGFloat
        let partiesHeight: CGFloat
        let lineItemsSectionTitleHeight: CGFloat
        let tableHeaderHeight: CGFloat
        let lineItemRowHeights: [UUID: CGFloat]
        let totalsGridHeight: CGFloat
        let footerBlockContentHeight: CGFloat

        /// Available vertical space inside page margins when page numbers are visible.
        var contentAreaHeight: CGFloat {
            max(printableHeight - pageNumberLabelHeight, 0)
        }

        func contentAreaHeight(showingPageNumbers: Bool) -> CGFloat {
            showingPageNumbers ? contentAreaHeight : printableHeight
        }

        static func make(
            paperSize: PaperSize,
            orientation: PageOrientation,
            marginPoints: CGFloat,
            measuredHeights: MeasuredHeights
        ) -> MeasuredDimensions {
            let pageSize = paperSize.sizePoints(for: orientation)
            let contentWidth = InvoiceLineItemsTypography.contentWidth(
                pageWidth: pageSize.width,
                margin: marginPoints
            )
            return MeasuredDimensions(
                printableHeight: pageSize.height - (marginPoints * 2),
                contentWidth: contentWidth,
                sectionSpacing: InvoiceDocumentLayout.sectionSpacing,
                lineItemsTitleSpacing: InvoiceDocumentLayout.lineItemsTitleSpacing,
                lineItemsTopPadding: InvoiceDocumentLayout.lineItemsTopPadding,
                pageNumberLabelHeight: measuredHeights.pageNumberLabelHeight,
                documentHeaderHeight: measuredHeights.documentHeaderHeight,
                partiesHeight: measuredHeights.partiesHeight,
                lineItemsSectionTitleHeight: measuredHeights.lineItemsSectionTitleHeight,
                tableHeaderHeight: measuredHeights.tableHeaderHeight,
                lineItemRowHeights: measuredHeights.lineItemRowHeights,
                totalsGridHeight: measuredHeights.totalsGridHeight,
                footerBlockContentHeight: measuredHeights.footerBlockContentHeight
            )
        }

        func firstPageOverhead(showsSectionTitle: Bool) -> CGFloat {
            documentHeaderHeight
                + sectionSpacing
                + partiesHeight
                + sectionSpacing
                + lineItemsTopPadding
                + (showsSectionTitle ? lineItemsSectionTitleHeight + lineItemsTitleSpacing : 0)
                + tableHeaderHeight
        }

        func continuationPageOverhead() -> CGFloat {
            tableHeaderHeight
        }

        func rowHeight(for itemID: UUID) -> CGFloat {
            lineItemRowHeights[itemID] ?? 0
        }

        func lineItemsHeight(for items: [InvoiceLineItemSnapshot], ids: [UUID]) -> CGFloat {
            guard !ids.isEmpty else { return 0 }
            let lookup = Dictionary(
                items.map { ($0.id, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            var total: CGFloat = 0
            for id in ids {
                guard lookup[id] != nil else { continue }
                total += rowHeight(for: id)
            }
            return total
        }
    }

    /// Height inputs for tests and the measurement pipeline.
    struct MeasuredHeights: Equatable {
        let pageNumberLabelHeight: CGFloat
        let documentHeaderHeight: CGFloat
        let partiesHeight: CGFloat
        let lineItemsSectionTitleHeight: CGFloat
        let tableHeaderHeight: CGFloat
        let lineItemRowHeights: [UUID: CGFloat]
        let totalsGridHeight: CGFloat
        let footerBlockContentHeight: CGFloat

        static func uniformRows(
            count: Int,
            rowHeight: CGFloat,
            printableHeight: CGFloat = 800,
            contentWidth: CGFloat = 523
        ) -> (MeasuredDimensions, [InvoiceLineItemSnapshot]) {
            let items = (0 ..< count).map { index in
                InvoiceLineItemSnapshot(
                    sortOrder: index,
                    itemDescription: "Service item \(index)",
                    quantity: 1,
                    unitPrice: 10,
                    taxRate: 0
                )
            }
            let rowHeights = Dictionary(
                items.map { ($0.id, rowHeight) },
                uniquingKeysWith: { first, _ in first }
            )
            let dimensions = MeasuredDimensions(
                printableHeight: printableHeight,
                contentWidth: contentWidth,
                sectionSpacing: 12,
                lineItemsTitleSpacing: 6,
                lineItemsTopPadding: 12,
                pageNumberLabelHeight: 20,
                documentHeaderHeight: 64,
                partiesHeight: 220,
                lineItemsSectionTitleHeight: 28,
                tableHeaderHeight: 32,
                lineItemRowHeights: rowHeights,
                totalsGridHeight: 112,
                footerBlockContentHeight: 128
            )
            return (dimensions, items)
        }
    }

    static func paginate(
        input: LayoutInput,
        dimensions: MeasuredDimensions
    ) -> [InvoicePageContent] {
        let footerHeight = dimensions.footerBlockContentHeight

        if input.lineItems.isEmpty {
            return [
                InvoicePageContent(
                    pageIndex: 0,
                    totalPages: 1,
                    showsDocumentHeader: true,
                    showsLineItemsSectionTitle: false,
                    lineItemIDs: [],
                    showsTableHeader: true,
                    showsTotals: true,
                    showsFooter: true
                ),
            ]
        }

        var itemPages = splitLineItemsAcrossPages(input: input, dimensions: dimensions)
        itemPages = ensureFooterFitsOnLastPage(
            itemPages: itemPages,
            input: input,
            dimensions: dimensions,
            footerHeight: footerHeight
        )

        let totalPages = itemPages.count
        return itemPages.enumerated().map { index, ids in
            let isFirst = index == 0
            let isLast = index == totalPages - 1
            return InvoicePageContent(
                pageIndex: index,
                totalPages: totalPages,
                showsDocumentHeader: isFirst,
                showsLineItemsSectionTitle: isFirst,
                lineItemIDs: ids,
                showsTableHeader: !ids.isEmpty,
                showsTotals: isLast,
                showsFooter: isLast
            )
        }
    }

    private static func splitLineItemsAcrossPages(
        input: LayoutInput,
        dimensions: MeasuredDimensions
    ) -> [[UUID]] {
        var pages: [[UUID]] = []
        var index = 0
        let items = input.lineItems

        while index < items.count {
            let isFirstPage = pages.isEmpty
            let overhead = isFirstPage
                ? dimensions.firstPageOverhead(showsSectionTitle: true)
                : dimensions.continuationPageOverhead()
            let capacity = dimensions.contentAreaHeight(
                showingPageNumbers: input.showPageNumbers
            ) - overhead

            var pageIDs: [UUID] = []
            var usedHeight: CGFloat = 0

            while index < items.count {
                let rowHeight = dimensions.rowHeight(for: items[index].id)
                if !pageIDs.isEmpty, usedHeight + rowHeight > capacity {
                    break
                }
                pageIDs.append(items[index].id)
                usedHeight += rowHeight
                index += 1
                if usedHeight >= capacity, index < items.count {
                    break
                }
            }

            pages.append(pageIDs)
        }

        return pages
    }

    private static func ensureFooterFitsOnLastPage(
        itemPages: [[UUID]],
        input: LayoutInput,
        dimensions: MeasuredDimensions,
        footerHeight: CGFloat
    ) -> [[UUID]] {
        guard !itemPages.isEmpty else { return [[]] }

        var pages = itemPages

        while true {
            let lastIndex = pages.count - 1
            let overhead = pageOverhead(for: lastIndex, metrics: dimensions)
            let itemsHeight = dimensions.lineItemsHeight(for: input.lineItems, ids: pages[lastIndex])
            let totalsHeight = dimensions.totalsGridHeight
            let remaining = dimensions.contentAreaHeight(
                showingPageNumbers: input.showPageNumbers
            ) - overhead - itemsHeight - totalsHeight

            if remaining >= footerHeight {
                return pages
            }

            if pages[lastIndex].count > 1 {
                let movedID = pages[lastIndex].removeLast()
                if lastIndex + 1 < pages.count {
                    pages[lastIndex + 1].insert(movedID, at: 0)
                } else {
                    pages.append([movedID])
                }
                continue
            }

            if pages[lastIndex].count == 1 {
                let loneItemID = pages[lastIndex][0]
                pages[lastIndex] = []
                pages.insert([loneItemID], at: lastIndex)
                continue
            }

            return pages
        }
    }

    private static func pageOverhead(
        for pageIndex: Int,
        metrics: MeasuredDimensions
    ) -> CGFloat {
        if pageIndex == 0 {
            return metrics.firstPageOverhead(showsSectionTitle: true)
        }
        return metrics.continuationPageOverhead()
    }
}
