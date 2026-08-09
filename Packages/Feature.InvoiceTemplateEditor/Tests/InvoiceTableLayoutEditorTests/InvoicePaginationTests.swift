import Testing
@testable import InvoiceTableLayoutEditor

@Suite struct InvoicePaginationTests {
    @Test func FooterOnlyContinuationPageDoesNotRenderEmptyTableHeader() {
        let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
            count: 1,
            rowHeight: 50,
            printableHeight: 500
        )

        let pages = InvoicePagination.paginate(
            input: makeInput(items: items),
            dimensions: dimensions
        )

        #expect(pages.count == 2)
        #expect(pages[0].lineItemIDs == [items[0].id])
        #expect(pages[0].showsTableHeader)
        #expect(!(pages[0].showsTotals))
        #expect(!(pages[0].showsFooter))
        #expect(pages[1].lineItemIDs.isEmpty)
        #expect(!(pages[1].showsTableHeader))
        #expect(pages[1].showsTotals)
        #expect(pages[1].showsFooter)
    }

    @Test func PaginationPreservesEveryLineItemExactlyOnceAndMarksOnlyLastPageFinal() {
        let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
            count: 20,
            rowHeight: 80,
            printableHeight: 500
        )

        let pages = InvoicePagination.paginate(
            input: makeInput(items: items),
            dimensions: dimensions
        )

        #expect(pages.flatMap(\.lineItemIDs) == items.map(\.id))
        #expect(pages.map(\.pageIndex) == Array(pages.indices))
        #expect(pages.dropLast().allSatisfy { !$0.showsTotals && !$0.showsFooter })
        #expect(pages.last?.showsTotals == true)
        #expect(pages.last?.showsFooter == true)
        #expect(pages.allSatisfy { $0.totalPages == pages.count })
    }

    private func makeInput(items: [InvoiceLineItemSnapshot]) -> InvoicePagination.LayoutInput {
        InvoicePagination.LayoutInput(
            lineItems: items,
            paperSize: .a4,
            pageOrientation: .portrait,
            marginPoints: 36,
            showPageNumbers: true
        )
    }
}
