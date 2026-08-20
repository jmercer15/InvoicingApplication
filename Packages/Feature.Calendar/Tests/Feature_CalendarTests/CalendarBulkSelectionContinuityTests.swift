import Foundation
import Core
import PersistenceModels
import SharedUI
@testable import Feature_Calendar
import Testing
import CoreTesting

@Suite(.tags(.integration))
struct CalendarBulkSelectionContinuityTests {
    @Test func bulkProgressClampsFractionAndBuildsReadableCopy() {
        let progress = CalendarBulkOperationProgress(
            action: "Marking Completed", completedCount: 2, totalCount: 5)
        #expect(progress.fractionCompleted == 0.4)
        #expect(progress.message == "Marking Completed 2 of 5")

        let over = CalendarBulkOperationProgress(
            action: "Deleting", completedCount: 8, totalCount: 5)
        #expect(over.fractionCompleted == 1.0)

        let under = CalendarBulkOperationProgress(
            action: "Cancelling", completedCount: -1, totalCount: 5)
        #expect(under.fractionCompleted == 0.0)
    }

    @Test func bulkStatusProgressCopyIsStatusAware() {
        #expect(CalendarBulkStatusProgressCopy.progressAction(for: .completed) == "Marking Completed")
        #expect(CalendarBulkStatusProgressCopy.progressAction(for: .cancelled) == "Cancelling")
        #expect(CalendarBulkStatusProgressCopy.progressAction(for: .scheduled) == "Marking Scheduled")
        #expect(CalendarBulkStatusProgressCopy.resultAction(for: .completed) == "Marked Completed")
        #expect(CalendarBulkStatusProgressCopy.resultAction(for: .cancelled) == "Cancelled")
        #expect(CalendarBulkStatusProgressCopy.progressAction(for: nil) == "Updating")
    }

    @Test func bulkFeedbackDistinguishesSuccessPartialAndFailure() {
        let success = CalendarBulkOperationFeedback.result(
            action: "Updated",
            succeeded: 3,
            skipped: 0,
            failed: 0
        )
        #expect(success.message == "Updated 3 sessions.")
        #expect(success.severity == .success)
        #expect(!(success.offersBillingHubPrepareStep))
        #expect(success.nextStepSubtitle == nil)

        let completedID = UUID()
        let partial = CalendarBulkOperationFeedback.result(
            action: "Marked Completed", succeeded: 2,
            skipped: 1,
            failed: 1,
            billingHubHandoffSessionIDs: [completedID],
            offersBillingHubPrepareStep: true)
        #expect(partial.message == "Marked Completed 2 sessions. Skipped 1 already invoiced. Failed 1.")
        #expect(partial.severity == .warning)
        #expect(partial.hasInvoicedSkips)
        #expect(partial.billingHubHandoffSessionIDs == [completedID])
        #expect(partial.offersBillingHubPrepareStep)
        #expect(partial.nextStepSubtitle == "Next: prepare in Billing Hub")

        let firstInvoice = UUID()
        let secondInvoice = UUID()
        let recovery = CalendarBulkOperationFeedback.result(
            action: "Updated", succeeded: 0,
            skipped: 2,
            failed: 0,
            invoicedInvoiceIDs: [firstInvoice, firstInvoice, secondInvoice])
        #expect(recovery.invoicedInvoiceIDs == [firstInvoice, secondInvoice])

        let failure = CalendarBulkOperationFeedback.result(
            action: "Deleted", succeeded: 0,
            skipped: 0,
            failed: 2)
        #expect(failure.message == "Failed 2.")
        #expect(failure.severity == .error)
        #expect(!failure.hasInvoicedSkips)
    }

    @Test func bulkDeleteConfirmationUsesPluralCopyAndExplainsInvoiceSkips() {
        #expect(CalendarBulkDeleteConfirmationCopy.title(count: 1) == "Delete Selected Session?")
        #expect(CalendarBulkDeleteConfirmationCopy.buttonTitle(count: 3) == "Delete 3 Sessions")
        #expect(CalendarBulkDeleteConfirmationCopy.message(count: 3, invoicedCount: 2) == "Deleted sessions cannot be recovered. 2 selected sessions are linked to invoices and will be skipped.")
    }

    @Test func travelPickerEnumsExposeHumanReadableRawValues() {
        #expect(TravelChargeSheetChargeType.standard.rawValue == "Standard Travel")
        #expect(TravelChargeSheetChargeType.activityBased.rawValue == "Activity-Based Transport")
        #expect(TravelChargeSheetDirection.before.rawValue == "Before Session")
        #expect(TravelChargeSheetDirection.after.rawValue == "After Session")
        #expect(TravelChargeSheetMMMZone.mmm1_3.rawValue == "Zones 1-3 (Metro)")
        #expect(TravelChargeSheetVehicleType.standard.rawValue == "Standard Car")
        #expect(TravelChargeSheetChargeType.standard.rawValue != String(describing: TravelChargeSheetChargeType.standard))
    }

    @Test func sessionStatusScheduledUsesSingleUserFacingLabel() {
        #expect(Core.SessionStatus.scheduled.displayName == "Scheduled")
        #expect(AppConstants.sessionStatusPlanned == AppConstants.sessionStatusConfirmed)
        #expect(AppConstants.sessionStatusPlanned == Core.SessionStatus.scheduled.token)
    }
}
