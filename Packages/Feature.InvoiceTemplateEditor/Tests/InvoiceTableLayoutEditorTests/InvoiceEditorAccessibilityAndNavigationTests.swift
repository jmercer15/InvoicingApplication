import XCTest
@testable import InvoiceTableLayoutEditor

@MainActor
final class InvoiceEditorAccessibilityAndNavigationTests: XCTestCase {

  // MARK: - 1. Document Preview Page Navigation Bounds & Shortcuts

  func testDefaultPageIndexIsZero() {
    let viewModel = InvoiceEditorViewModel()
    XCTAssertEqual(viewModel.currentPageIndex, 0)
    XCTAssertGreaterThanOrEqual(viewModel.totalPages, 1)
  }

  func testGoToNextPageAndPreviousPage() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 20,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let totalPages = viewModel.totalPages
    XCTAssertGreaterThan(totalPages, 1)

    viewModel.goToFirstPage()
    XCTAssertEqual(viewModel.currentPageIndex, 0)

    viewModel.goToNextPage()
    XCTAssertEqual(viewModel.currentPageIndex, 1)

    viewModel.goToPreviousPage()
    XCTAssertEqual(viewModel.currentPageIndex, 0)
  }

  func testGoToFirstPageAndGoToLastPage() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 20,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let totalPages = viewModel.totalPages
    XCTAssertGreaterThan(totalPages, 1)

    viewModel.goToLastPage()
    XCTAssertEqual(viewModel.currentPageIndex, totalPages - 1)

    viewModel.goToFirstPage()
    XCTAssertEqual(viewModel.currentPageIndex, 0)
  }

  func testPageIndexClampingOutOfBounds() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 20,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let totalPages = viewModel.totalPages

    viewModel.goToPage(-10)
    XCTAssertEqual(viewModel.currentPageIndex, 0)

    viewModel.goToPage(999)
    XCTAssertEqual(viewModel.currentPageIndex, totalPages - 1)
  }

  func testPageIndexClampingWhenPageCountReduces() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 20,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let initialTotalPages = viewModel.totalPages
    XCTAssertGreaterThan(initialTotalPages, 1)

    viewModel.goToLastPage()
    XCTAssertEqual(viewModel.currentPageIndex, initialTotalPages - 1)

    let (singlePageDimensions, singleItem) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 1,
      rowHeight: 30,
      printableHeight: 800
    )
    viewModel.lineItems = singleItem
    viewModel.updateMeasuredDimensions(singlePageDimensions)

    XCTAssertEqual(viewModel.totalPages, 1)
    XCTAssertEqual(viewModel.currentPageIndex, 0)
  }

  // MARK: - 2. Save-Failure Recovery Banner Accessibility & Focus

  func testSaveFailureBannerToneIsError() {
    let failureMessages = [
      "Save failed. Template changes couldn't be saved.",
      "Template couldn't be saved.",
      "Failed to save invoice changes.",
      "Invoice could not be saved."
    ]

    for message in failureMessages {
      XCTAssertTrue(
        InvoiceEditorStatusBanner.isError(message),
        "Expected '\(message)' to be categorized as error tone"
      )
      XCTAssertEqual(
        InvoiceEditorStatusBanner.tone(for: message),
        .error
      )
      XCTAssertFalse(
        InvoiceEditorStatusBanner.shouldAutoDismiss(message),
        "Error status messages should not auto-dismiss"
      )
    }
  }

  func testStatusBannerSuppressionWhenTemplateSaveFailed() {
    let errorMessage = "Invoice couldn't be created."
    let infoMessage = "Applied Classic template."

    XCTAssertEqual(
      InvoiceEditorStatusBanner.messageForPresentation(errorMessage, whileTemplateSaveFailed: true),
      errorMessage
    )
    XCTAssertNil(
      InvoiceEditorStatusBanner.messageForPresentation(infoMessage, whileTemplateSaveFailed: true)
    )
  }

  // MARK: - 3. Validated Decimal Fields Error Feedback

  func testDecimalInputParsingValidAndInvalidValues() {
    XCTAssertNotNil(InvoiceDecimalInput.parse("123.45"))
    XCTAssertEqual(InvoiceDecimalInput.parse("123.45"), Decimal(string: "123.45"))
    XCTAssertNil(InvoiceDecimalInput.parse(""))
    XCTAssertNil(InvoiceDecimalInput.parse("   "))
    XCTAssertNil(InvoiceDecimalInput.parse("abc"))
    XCTAssertNil(InvoiceDecimalInput.parse("12.34.56"))
  }

  func testDoubleInputParsingWithinAndOutsideRange() {
    let range: ClosedRange<Double> = 0.5...10.0

    XCTAssertEqual(InvoiceDoubleInput.parse("5.0", in: range), 5.0)
    XCTAssertEqual(InvoiceDoubleInput.parse("0.5", in: range), 0.5)
    XCTAssertEqual(InvoiceDoubleInput.parse("10.0", in: range), 10.0)

    // Out of range
    XCTAssertNil(InvoiceDoubleInput.parse("0.4", in: range))
    XCTAssertNil(InvoiceDoubleInput.parse("10.1", in: range))
    XCTAssertNil(InvoiceDoubleInput.parse("-1.0", in: range))

    // Invalid non-numeric input
    XCTAssertNil(InvoiceDoubleInput.parse("invalid", in: range))
    XCTAssertNil(InvoiceDoubleInput.parse("", in: range))
  }

  func testDoubleInputStringFormatting() {
    let text = InvoiceDoubleInput.string(for: 1.5)
    XCTAssertFalse(text.isEmpty)
    XCTAssertEqual(InvoiceDoubleInput.parse(text, in: 0.0...10.0), 1.5)
  }
}
