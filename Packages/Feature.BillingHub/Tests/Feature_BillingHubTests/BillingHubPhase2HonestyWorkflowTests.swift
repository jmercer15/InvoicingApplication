import Foundation
import Core
import PersistenceModels
import Data
import SwiftData
import Testing
import CoreTesting
@testable import Feature_BillingHub

@MainActor
@Suite(.tags(.integration))
struct BillingHubPhase2HonestyWorkflowTests {
    @Test func upsertSupportLogUpdatesExistingLog() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let session = BillingHubPhase2HonestyFixtures.makeSession()
        context.insert(session)
        try context.save()

        var draft = SupportLogDraft()
        draft.participantName = "Pat"
        draft.participantNdisNumber = "4300000001"
        draft.supportItemNumber = "01_011_0107_1_1"
        draft.serviceDescription = "Support"
        draft.location = "Clinic"
        draft.deliveredBy = "Worker"
        draft.attestedBy = "Worker"
        draft.notes = "first"
        try await workflow.upsertSupportLog(sessionModelID: session.persistentModelID, draft: draft)

        draft.notes = "updated"
        draft.attestedAt = Date().addingTimeInterval(60)
        try await workflow.upsertSupportLog(sessionModelID: session.persistentModelID, draft: draft)

        let verify = ModelContext(container)
        let logs = try verify.fetch(FetchDescriptor<SupportLog>())
        #expect(logs.count == 1)
        #expect(logs.first?.notes == "updated")
    }

    @Test func finalizePaymentWarnsWhenAmountDiffersButStillSucceeds() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "PAY-WARN-001")
        invoice.status = .pending
        invoice.totalAmount = 100
        context.insert(invoice)
        try context.save()

        let saved = await viewModel.finalizePayment(
            id: invoice.id,
            amount: "40.00",
            date: Date(),
            method: "Cash",
            reference: "partial"
        )
        #expect(saved)
        #expect(viewModel.bulkActionFeedback?.contains("remains outstanding") == true)
        #expect(BillingHubBulkFeedbackSeverity.classify(viewModel.bulkActionFeedback ?? "") == .warning
        )
        #expect(try context.fetch(FetchDescriptor<Invoice>()).first?.status == Optional(.received))
    }

    @Test func finalizePaymentMissingInvoiceSetsFeedback() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let saved = await viewModel.finalizePayment(
            id: UUID(),
            amount: "10.00",
            date: Date(),
            method: "Cash",
            reference: ""
        )
        #expect(!saved)
        #expect(viewModel.bulkActionFeedback == "Invoice could not be found.")
    }

    @Test func savePaymentDraftRejectsInvalidAmount() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "PAY-ZERO-001")
        invoice.status = .pending
        context.insert(invoice)
        try context.save()

        let saved = await viewModel.savePaymentDraft(
            id: invoice.id,
            amount: "0",
            date: Date(),
            method: "Cash",
            reference: ""
        )
        #expect(!saved)
        #expect(viewModel.bulkActionFeedback == "Enter a payment amount greater than zero.")
        #expect(try context.fetch(FetchDescriptor<Invoice>()).first?.notes == nil)    }
    @Test func reopenInvoiceAsPendingStripsPaymentNote() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "REOPEN-NOTE-001")
        invoice.status = .received
        invoice.paidDate = Date()
        invoice.sentDate = Date(timeIntervalSince1970: 1_700_000_000)
        invoice.notes = "Keep me\nPayment: 40.00 via Cash on 1 Jan 2026\nAlso keep"
        context.insert(invoice)
        try context.save()

        let didReopen = await viewModel.reopenInvoiceAsPending(id: invoice.id)
        #expect(didReopen)

        let refreshed = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
        #expect(refreshed.status == Optional(.pending))
        #expect(refreshed.paidDate == nil)
        #expect(refreshed.sentDate == Date(timeIntervalSince1970: 1_700_000_000))
        #expect(refreshed.notes == "Keep me\nAlso keep")
        #expect(refreshed.notes?.contains("Payment:") == false)
        #expect(viewModel.bulkActionFeedback == "Invoice reopened as Sent. Paid date and payment details cleared.")
    }

    @Test func reopenInvoiceAsPendingRejectsInvoiceWithoutPaymentReceived() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: StubNDISBillingIntegrationService(
                response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
            )
        )
        let invoice = Invoice(id: UUID(), invoiceNumber: "REOPEN-NOT-PAID-001")
        invoice.status = .pending
        context.insert(invoice)
        try context.save()

        let didReopen = await viewModel.reopenInvoiceAsPending(id: invoice.id)
        #expect(!didReopen)
        #expect(viewModel.bulkActionFeedback == "Only invoices with payment received can be reopened as Sent."
        )
        #expect(try context.fetch(FetchDescriptor<Invoice>()).first?.status == .pending)
    }

    @Test func removingPaymentLineHelper() {
        #expect(BillingHubPaymentNoteFormatter.removingPaymentLine(from: nil) == nil)
        #expect(BillingHubPaymentNoteFormatter.removingPaymentLine(from: "Payment: only") == nil)
        #expect(BillingHubPaymentNoteFormatter.removingPaymentLine(from: "A\nPayment: x\nB") == "A\nB")
        #expect(
            BillingHubPaymentNoteFormatter.paymentLine(from: "A\nPayment: $42.50 via Cash\nB")
                == "Payment: $42.50 via Cash"
        )
        #expect(BillingHubPaymentNoteFormatter.paymentLine(from: "A\nB") == nil)
    }

    @Test func persistedTravelChargeTypeMapsHubStandard() {
        #expect(BillingHubWorkflowActor.persistedTravelChargeType("Standard") == .standard)
        #expect(BillingHubWorkflowActor.persistedTravelChargeType("standard") == .standard)
        #expect(BillingHubWorkflowActor.persistedTravelChargeType("labour") == .labour)
        #expect(TravelChargeType(rawValue: "standard") == nil)
    }

    @Test func addTravelPersistsHubStandardAsNonNilType() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let session = BillingHubPhase2HonestyFixtures.makeSession()
        context.insert(session)
        try context.save()

        try await workflow.addTravelCharge(
            sessionModelID: session.persistentModelID, distance: 10,
            time: 15,
            tolls: 0,
            parking: 0,
            chargeType: "Standard",
            vehicleType: "Standard Car",
            travelDirection: "before",
            participantCount: 1,
            splitCosts: false)

        let verify = ModelContext(container)
        let charges = try verify.fetch(FetchDescriptor<TravelCharge>())
        #expect(charges.count == 1)
        #expect(charges.first?.chargeType == .standard)
    }

    @Test func ungroupDissolvesSingletonRemainingMember() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let groupID = UUID()
        let leaving = BillingHubPhase2HonestyFixtures.makeSession()
        leaving.groupID = groupID
        leaving.status = .grouped
        let remaining = BillingHubPhase2HonestyFixtures.makeSession()
        remaining.title = "Remaining"
        remaining.groupID = groupID
        remaining.status = .grouped
        context.insert(leaving)
        context.insert(remaining)
        try context.save()

        try await workflow.ungroupSessions(modelIDs: [leaving.persistentModelID])

        let verify = ModelContext(container)
        let sessions = try verify.fetch(FetchDescriptor<Session>())
        let left = try #require(sessions.first { $0.id == leaving.id })
        let stay = try #require(sessions.first { $0.id == remaining.id })
        #expect(left.groupID == nil)
#expect(stay.groupID == nil, "singleton leftover group must dissolve")
    }

    @Test func upsertSupportLogPersistsQuantityHours() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let session = BillingHubPhase2HonestyFixtures.makeSession()
        context.insert(session)
        try context.save()

        var draft = SupportLogDraft()
        draft.participantName = "Pat"
        draft.participantNdisNumber = "4300000001"
        draft.supportItemNumber = "01_011_0107_1_1"
        draft.serviceDescription = "Support"
        draft.location = "Clinic"
        draft.deliveredBy = "Worker"
        draft.attestedBy = "Worker"
        draft.quantityHours = 2.5
        try await workflow.upsertSupportLog(sessionModelID: session.persistentModelID, draft: draft)

        let verify = ModelContext(container)
        let logs = try verify.fetch(FetchDescriptor<SupportLog>())
        #expect(logs.first?.quantityHours ?? -1 == 2.5) // was accuracy: 0.001
    }

}
