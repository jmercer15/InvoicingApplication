import Foundation
import Testing
import SwiftUI
@testable import InvoiceTableLayoutEditor

@MainActor
@Suite struct RequirementR2StressTests {

  // MARK: - 1. Page Navigation Shortcuts & Boundary Limits

  @Test func SinglePageNavigationShortcutsAreNoOps() {
    let viewModel = InvoiceEditorViewModel()
    // Single page document by default
    #expect(viewModel.totalPages == 1)
    #expect(viewModel.currentPageIndex == 0)

    // Triggering shortcuts on single page
    viewModel.goToNextPage()
    #expect(viewModel.currentPageIndex == 0, "Next page on single page document must stay 0")

    viewModel.goToPreviousPage()
    #expect(viewModel.currentPageIndex == 0, "Previous page on single page document must stay 0")

    viewModel.goToFirstPage()
    #expect(viewModel.currentPageIndex == 0, "First page on single page document must stay 0")

    viewModel.goToLastPage()
    #expect(viewModel.currentPageIndex == 0, "Last page on single page document must stay 0")
  }

  @Test func MultiPageNavigationShortcutsAndBoundaryLimits() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 30,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let total = viewModel.totalPages
    #expect(total > 1, "Should have multiple pages")

    // Start at 0
    #expect(viewModel.currentPageIndex == 0)

    // Go to next page
    viewModel.goToNextPage()
    #expect(viewModel.currentPageIndex == 1)

    // Go to last page
    viewModel.goToLastPage()
    #expect(viewModel.currentPageIndex == total - 1)

    // Attempt next page past last page (Page N+1)
    viewModel.goToNextPage()
    #expect(viewModel.currentPageIndex == total - 1, "Cannot navigate past last page")

    // Go to first page
    viewModel.goToFirstPage()
    #expect(viewModel.currentPageIndex == 0)

    // Attempt previous page before first page (Page -1)
    viewModel.goToPreviousPage()
    #expect(viewModel.currentPageIndex == 0, "Cannot navigate before page 0")

    // Direct out of bounds page index assignments
    viewModel.goToPage(-5)
    #expect(viewModel.currentPageIndex == 0, "Negative index must clamp to 0")

    viewModel.goToPage(999)
    #expect(viewModel.currentPageIndex == total - 1, "Excessive index must clamp to totalPages - 1")
  }

  @Test func StalePageIndexWhenLineItemsAreRemovedWithoutDimensionUpdate() {
    let viewModel = InvoiceEditorViewModel()
    let (dimensions, items) = InvoicePagination.MeasuredHeights.uniformRows(
      count: 30,
      rowHeight: 80,
      printableHeight: 300
    )
    viewModel.lineItems = items
    viewModel.updateMeasuredDimensions(dimensions)

    let initialTotal = viewModel.totalPages
    #expect(initialTotal > 1)

    // Navigate to page 2 (last page)
    viewModel.goToLastPage()
    let pageBeforeDelete = viewModel.currentPageIndex
    #expect(pageBeforeDelete == initialTotal - 1)

    // Remove all line items
    viewModel.removeLineItems(at: IndexSet(integersIn: 0..<items.count))

    // Total pages shrinks to 1 and page index clamps back into range.
    #expect(viewModel.totalPages == 1)
    #expect(viewModel.currentPageIndex == 0)
    #expect(viewModel.currentPageIndex != pageBeforeDelete, "Removing line items must clamp page index when pagination collapses")
  }

  // MARK: - 2. Save Failure Banner & Focus Handling

  @Test func SaveFailureBannerToneAndDismissal() {
    let errorMessage = "Save failed. Database full."
    #expect(InvoiceEditorStatusBanner.isError(errorMessage))
    #expect(InvoiceEditorStatusBanner.tone(for: errorMessage) == .error)
    #expect(!(InvoiceEditorStatusBanner.shouldAutoDismiss(errorMessage)))

    let viewModel = InvoiceEditorViewModel()
    viewModel.statusMessage = errorMessage
    let initialID = viewModel.statusMessageID

    // Re-assigning same message string updates statusMessageID
    viewModel.statusMessage = errorMessage
    #expect(viewModel.statusMessageID != initialID, "Setting statusMessage generates new message ID")

    // Dismiss status message
    viewModel.dismissStatusMessage(id: viewModel.statusMessageID)
    #expect(viewModel.statusMessage == nil)
  }

  @Test func TemplateSaveFailureBannerRecoveryPolicy() {
    // Check recovery issue states
    let issue = InvoiceTemplateSaveRecoveryPolicy.issue(
      saveState: .failed,
      hasInvalidInputs: false
    )
    #expect(issue == .saveFailure)

    // State reconciled when requiresSave becomes false
    let reconciled = InvoiceTemplateSaveRecoveryPolicy.reconciledState(.failed, requiresSave: false)
    #expect(reconciled == .saved)
  }

  // MARK: - 3. Decimal Field Parsing & Extreme Locales / Rapid Typing

  @Test func DecimalInputParsingStandardUS() {
    let locale = Locale(identifier: "en_US")
    #expect(InvoiceDecimalInput.parse("123.45", locale: locale) == Decimal(string: "123.45"))
    #expect(InvoiceDecimalInput.parse("1,234.56", locale: locale) == Decimal(string: "1234.56"))
    #expect(InvoiceDecimalInput.parse("0", locale: locale) == Decimal(0))
  }

  @Test func DecimalInputParsingFrenchLocaleSpacesAndCommas() {
    let frLocale = Locale(identifier: "fr_FR")

    // In French locale, comma is decimal separator
    #expect(InvoiceDecimalInput.parse("1234,56", locale: frLocale) == Decimal(string: "1234.56"))

    // Regular space keyboard input: "1 234,56" in macOS fr_FR locale parses successfully as 1234.56
    #expect(InvoiceDecimalInput.parse("1 234,56", locale: frLocale) == Decimal(string: "1234.56"))

    // Non-breaking space \u{00A0} is also valid
    #expect(InvoiceDecimalInput.parse("1\u{00A0}234,56", locale: frLocale) == Decimal(string: "1234.56"))
  }

  @Test func DecimalInputParsingGermanLocaleDotVsComma() {
    let deLocale = Locale(identifier: "de_DE")

    // In German locale, comma is decimal separator: "1234,56"
    #expect(InvoiceDecimalInput.parse("1234,56", locale: deLocale) == Decimal(string: "1234.56"))

    // Numeric keypad often emits '.' even when locale decimal separator is ','.
    let keypadDotString = "1234.56"
    let parsedKeypadDot = InvoiceDecimalInput.parse(keypadDotString, locale: deLocale)
    #expect(parsedKeypadDot == Decimal(string: "1234.56"), "Keypad-style '.' decimal must parse in locales that use ',' as decimal separator")
  }

  @Test func RapidTypingIntermediateDecimalPointState() {
    let locale = Locale(identifier: "en_US")

    // EMPIRICAL DISCOVERY: Mid-typing state when user types "12."
    // NumberFormatter parses "12." as valid integer 12 (consuming all 3 characters).
    let intermediateDot = InvoiceDecimalInput.parse("12.", locale: locale)
    #expect(intermediateDot == Decimal(12), "Confirmed: NumberFormatter parses trailing dot '12.' as Decimal(12)")

    // However, if text synchronization occurs before next character is typed, string(for: 12) strips the trailing dot.
    let formattedBack = InvoiceDecimalInput.string(for: Decimal(12), locale: locale)
    #expect(formattedBack == "12", "Confirmed: Re-formatting 12 drops trailing '.' during rapid typing pause")
  }
}
