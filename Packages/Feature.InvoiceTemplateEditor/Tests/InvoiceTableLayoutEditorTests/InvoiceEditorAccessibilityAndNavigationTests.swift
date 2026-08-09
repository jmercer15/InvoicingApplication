import Foundation
import Testing
@testable import InvoiceTableLayoutEditor

@MainActor
@Suite struct InvoiceEditorAccessibilityAndNavigationTests {

  // MARK: - 1. Document Preview Page Navigation Bounds & Shortcuts

  @Test func DefaultPageIndexIsZero() {
    let viewModel = InvoiceEditorViewModel()
    #expect(viewModel.currentPageIndex == 0)
    #expect(viewModel.totalPages >= 1)
  }

  @Test func GoToNextPageAndPreviousPage() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 20,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let totalPages = viewModel.totalPages
    #expect(totalPages > 1)

    viewModel.goToFirstPage()
    #expect(viewModel.currentPageIndex == 0)

    viewModel.goToNextPage()
    #expect(viewModel.currentPageIndex == 1)

    viewModel.goToPreviousPage()
    #expect(viewModel.currentPageIndex == 0)
  }

  @Test func GoToFirstPageAndGoToLastPage() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 20,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let totalPages = viewModel.totalPages
    #expect(totalPages > 1)

    viewModel.goToLastPage()
    #expect(viewModel.currentPageIndex == totalPages - 1)

    viewModel.goToFirstPage()
    #expect(viewModel.currentPageIndex == 0)
  }

  @Test func PageIndexClampingOutOfBounds() {
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
    #expect(viewModel.currentPageIndex == 0)

    viewModel.goToPage(999)
    #expect(viewModel.currentPageIndex == totalPages - 1)
  }

  @Test func PageIndexClampingWhenPageCountReduces() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 20,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let initialTotalPages = viewModel.totalPages
    #expect(initialTotalPages > 1)

    viewModel.goToLastPage()
    #expect(viewModel.currentPageIndex == initialTotalPages - 1)

    let (singlePageDimensions, singleItem) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 1,
      rowHeight: 30,
      printableHeight: 800
    )
    viewModel.lineItems = singleItem
    viewModel.updateMeasuredDimensions(singlePageDimensions)

    #expect(viewModel.totalPages == 1)
    #expect(viewModel.currentPageIndex == 0)
  }

  // MARK: - 2. Save-Failure Recovery Banner Accessibility & Focus

  @Test func SaveFailureBannerToneIsError() {
    let failureMessages = [
      "Save failed. Template changes couldn't be saved.",
      "Template couldn't be saved.",
      "Failed to save invoice changes.",
      "Invoice could not be saved."
    ]

    for message in failureMessages {
      #expect(InvoiceEditorStatusBanner.isError(message), "Expected '\(message)' to be categorized as error tone")
      #expect(InvoiceEditorStatusBanner.tone(for: message) == .error)
      #expect(!(InvoiceEditorStatusBanner.shouldAutoDismiss(message)), "Error status messages should not auto-dismiss")
    }
  }

  @Test func StatusBannerSuppressionWhenTemplateSaveFailed() {
    let errorMessage = "Invoice couldn't be created."
    let infoMessage = "Applied Classic template."

    #expect(InvoiceEditorStatusBanner.messageForPresentation(errorMessage, whileTemplateSaveFailed: true) == errorMessage)
    #expect(InvoiceEditorStatusBanner.messageForPresentation(infoMessage, whileTemplateSaveFailed: true) == nil)
  }

  // MARK: - 3. Validated Decimal Fields Error Feedback

  @Test func DecimalInputParsingValidAndInvalidValues() {
    #expect(InvoiceDecimalInput.parse("123.45") != nil)
    #expect(InvoiceDecimalInput.parse("123.45") == Decimal(string: "123.45"))
    #expect(InvoiceDecimalInput.parse("") == nil)
    #expect(InvoiceDecimalInput.parse("   ") == nil)
    #expect(InvoiceDecimalInput.parse("abc") == nil)
    #expect(InvoiceDecimalInput.parse("12.34.56") == nil)
  }

  @Test func DoubleInputParsingWithinAndOutsideRange() {
    let range: ClosedRange<Double> = 0.5...10.0

    #expect(InvoiceDoubleInput.parse("5.0", in: range) == 5.0)
    #expect(InvoiceDoubleInput.parse("0.5", in: range) == 0.5)
    #expect(InvoiceDoubleInput.parse("10.0", in: range) == 10.0)

    // Out of range
    #expect(InvoiceDoubleInput.parse("0.4", in: range) == nil)
    #expect(InvoiceDoubleInput.parse("10.1", in: range) == nil)
    #expect(InvoiceDoubleInput.parse("-1.0", in: range) == nil)

    // Invalid non-numeric input
    #expect(InvoiceDoubleInput.parse("invalid", in: range) == nil)
    #expect(InvoiceDoubleInput.parse("", in: range) == nil)
  }

  @Test func DoubleInputStringFormatting() {
    let text = InvoiceDoubleInput.string(for: 1.5)
    #expect(!(text.isEmpty))
    #expect(InvoiceDoubleInput.parse(text, in: 0.0...10.0) == 1.5)
  }
}
