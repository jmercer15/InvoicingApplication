import XCTest
@testable import InvoiceTableLayoutEditor

final class InvoicePaginationTests: XCTestCase {
    func testFooterOnlyContinuationPageDoesNotRenderEmptyTableHeader() {
        let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
            count: 1,
            rowHeight: 50,
            printableHeight: 500
        )

        let pages = InvoicePagination.paginate(
            input: makeInput(items: items),
            dimensions: dimensions
        )

        XCTAssertEqual(pages.count, 2)
        XCTAssertEqual(pages[0].lineItemIDs, [items[0].id])
        XCTAssertTrue(pages[0].showsTableHeader)
        XCTAssertFalse(pages[0].showsTotals)
        XCTAssertFalse(pages[0].showsFooter)
        XCTAssertTrue(pages[1].lineItemIDs.isEmpty)
        XCTAssertFalse(pages[1].showsTableHeader)
        XCTAssertTrue(pages[1].showsTotals)
        XCTAssertTrue(pages[1].showsFooter)
    }

    func testPaginationPreservesEveryLineItemExactlyOnceAndMarksOnlyLastPageFinal() {
        let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
            count: 20,
            rowHeight: 80,
            printableHeight: 500
        )

        let pages = InvoicePagination.paginate(
            input: makeInput(items: items),
            dimensions: dimensions
        )

        XCTAssertEqual(pages.flatMap(\.lineItemIDs), items.map(\.id))
        XCTAssertEqual(pages.map(\.pageIndex), Array(pages.indices))
        XCTAssertTrue(pages.dropLast().allSatisfy { !$0.showsTotals && !$0.showsFooter })
        XCTAssertTrue(pages.last?.showsTotals == true)
        XCTAssertTrue(pages.last?.showsFooter == true)
        XCTAssertTrue(pages.allSatisfy { $0.totalPages == pages.count })
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
