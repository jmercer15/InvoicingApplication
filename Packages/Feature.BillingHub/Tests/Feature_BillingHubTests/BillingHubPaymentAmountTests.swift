import PersistenceModels
import Testing
@testable import Feature_BillingHub

@Suite(.tags(.integration))
struct BillingHubPaymentAmountTests {
    @Test func rejectsEmptyZeroAndNonNumeric() {
        #expect(!(BillingHubPaymentAmount.isValid("")))
        #expect(!(BillingHubPaymentAmount.isValid("   ")))
        #expect(!(BillingHubPaymentAmount.isValid("0")))
        #expect(!(BillingHubPaymentAmount.isValid("0.00")))
        #expect(!(BillingHubPaymentAmount.isValid("abc")))
    }

    @Test func acceptsPositiveAmountsWithCommaOrDot() {
        #expect(BillingHubPaymentAmount.isValid("12.50"))
        #expect(BillingHubPaymentAmount.isValid("12,50"))
        #expect(BillingHubPaymentAmount.isValid(" 1 "))
        #expect(abs((BillingHubPaymentAmount.parsedValue("12,5") ?? -1) - 12.5) <= 0.001)
        #expect(abs((BillingHubPaymentAmount.parsedValue("$1,234.56") ?? -1) - 1234.56) <= 0.001)
        #expect(abs((BillingHubPaymentAmount.parsedValue("AUD 1,234.56") ?? -1) - 1234.56) <= 0.001)
        #expect(abs((BillingHubPaymentAmount.parsedValue("1,234") ?? -1) - 1234) <= 0.001)
    }

    @Test func mismatchWarningWhenAmountDiffersFromTotal() {
        #expect(BillingHubPaymentAmount.mismatchWarning(entered: "100.00", invoiceTotal: 100.00) == nil)
        #expect(BillingHubPaymentAmount.mismatchWarning(entered: "100.005", invoiceTotal: 100.00) == nil)
        #expect(BillingHubPaymentAmount.mismatchWarning(entered: "50.00", invoiceTotal: 100.00) == "Partial payment — $50.00 remains outstanding.")
        #expect(BillingHubPaymentAmount.mismatchWarning(entered: "125.00", invoiceTotal: 100.00) == "Overpayment — $25.00 exceeds the invoice total.")
    }

    @Test func mismatchConfirmationNamesStatusChangingConsequence() {
        let partial = BillingHubPaymentAmount.mismatchConfirmation(
            entered: "40",
            invoiceTotal: 100
        )
        let overpayment = BillingHubPaymentAmount.mismatchConfirmation(
            entered: "120",
            invoiceTotal: 100
        )

        #expect(partial?.title == "Record Partial Payment?")
        #expect(partial?.message.contains("$60.00 outstanding") == true)
        #expect(partial?.message.contains("Payment Received") == true)
        #expect(overpayment?.buttonTitle == "Record Overpayment")
        #expect(overpayment?.message.contains("$20.00 overpayment") == true)
    }
}

@Suite(.tags(.integration))
struct BillingHubLaneNamingTests {
    @Test func receivedLaneNoLongerCollidesWithSessionCompleted() {
        #expect(KanbanCardData.BillingColumnType.completed.laneTitle == "Completed")
        #expect(KanbanCardData.BillingColumnType.pending.laneTitle == "Sent")
        #expect(KanbanCardData.BillingColumnType.received.laneTitle == "Payment Received")
        #expect(KanbanCardData.BillingColumnType.completed.laneTitle != KanbanCardData.BillingColumnType.received.laneTitle)
    }

    @Test func singularRecordTitlesDoNotReusePluralLaneTitles() {
        #expect(KanbanCardData.WorkflowStatus.readyToInvoice.recordTitle == "Travel Review")
        #expect(KanbanCardData.WorkflowStatus.draftReview.recordTitle == "Draft Review")
        #expect(KanbanCardData.WorkflowStatus.pendingPayment.recordTitle == "Sent")
        #expect(KanbanCardData.WorkflowStatus.paymentReceived.recordTitle == "Payment Received")
    }

    @Test func boardItemCountsUseCorrectGrammar() {
        #expect(BillingHubBoardCopy.itemCount(0) == "0 items")
        #expect(BillingHubBoardCopy.itemCount(1) == "1 item")
        #expect(BillingHubBoardCopy.itemCount(2) == "2 items")
    }

    @Test func boardSectionsMapEveryLaneForFocusContinuity() {
        #expect(BillingHubBoardSectionID.section(containing: .completed) == .preparing)
        #expect(BillingHubBoardSectionID.section(containing: .readyToSend) == .processing)
        #expect(BillingHubBoardSectionID.section(containing: .received) == .payment)

        let mappedColumns = Set(
            BillingHubBoardSectionID.allCases.flatMap(\.columns)
        )
        #expect(mappedColumns == Set(KanbanCardData.BillingColumnType.allCases))
    }

    @Test func transitionFeedbackNamesDestinationLane() {
        #expect(BillingHubBoardCopy.movedRecord("Session", to: .grouped) == "Session moved to Grouped.")
        #expect(BillingHubBoardCopy.movedRecord("Invoice", to: .readyToSend) == "Invoice moved to Ready to Send.")
        #expect(
            BillingHubBoardCopy.movedInvoiceWithComplianceWarnings(to: .readyToSend)
                == "Invoice moved to Ready to Send with compliance warnings. Review details before the next step."
        )
    }

    @Test func filteredEmptyLaneExplainsHowToRestoreWork() {
        #expect(BillingHubBoardCopy.emptyLaneMessage(for: .readyToSend, hasActiveFilters: false) == "Approve a draft in Review Drafts to queue it for sending.")
        #expect(BillingHubBoardCopy.emptyLaneMessage(for: .readyToSend, hasActiveFilters: true) == "No matching ready to send work. Clear filters to see all billing work.")
    }

    @Test func feedbackOffersClearFiltersRecoveryOnlyWhenNamed() {
        #expect(BillingHubBoardCopy.offersClearFiltersRecovery(
            for: "Could not find that item on the board. Try Clear filters."
        ))
        #expect(!(BillingHubBoardCopy.offersClearFiltersRecovery(for: "Invoice moved to Sent.")))
    }
}
