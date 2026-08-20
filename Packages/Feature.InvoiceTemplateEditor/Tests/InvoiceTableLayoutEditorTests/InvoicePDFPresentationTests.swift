import Core
import PersistenceModels
import Data
import Foundation
import SwiftData
import Testing
import CoreTesting
@testable import InvoiceTableLayoutEditor

@Suite(.tags(.integration))
struct InvoicePDFPresentationTests {
    @Test func receiptSummaryIncludesPaidDateAndPaymentNote() {
        let paidDate = Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 25))!
        let notes = "Thanks\nPayment: $120.00 via Bank Transfer on 25 Jul 2026 ref ABC\nOther"
        let summary = InvoicePDFPresentation.receiptSummary(paidDate: paidDate, notes: notes)

        #expect(summary.contains("Paid on"))
        #expect(summary.contains("Payment: $120.00 via Bank Transfer"))
    }

    @Test func receiptSummaryOmitsMissingPieces() {
        #expect(InvoicePDFPresentation.receiptSummary(paidDate: nil, notes: nil) == "")
        #expect(InvoicePDFPresentation.receiptSummary(paidDate: nil, notes: "No payment line") == "")
    }

    @MainActor
    @Test func viewModelReceiptOverridesLeavePersistedFieldsUntouched() throws {
        let container = try ModelContainerFactory.makeInMemoryContainer()
        let viewModel = InvoiceEditorViewModel(
            actor: InvoiceModelActor(modelContainer: container)
        )
        viewModel.title = "Tax Invoice"
        viewModel.notes = "Existing notes"

        viewModel.applyPDFPresentation(
            .receipt(paymentSummary: "Paid on 25 Jul 2026\nPayment: $10 via Cash on 25 Jul 2026")
        )

        #expect(viewModel.documentTitleForRender == "Receipt")
        #expect(viewModel.notesForRender.contains("Paid on"))
        #expect(viewModel.notesForRender.contains("Existing notes"))
        #expect(viewModel.title == "Tax Invoice")
        #expect(viewModel.notes == "Existing notes")

        viewModel.clearPDFPresentationOverrides()
        #expect(viewModel.documentTitleForRender == "Tax Invoice")
        #expect(viewModel.notesForRender == "Existing notes")
    }
}
