import Foundation
import Core
import PersistenceModels
import Data
import SwiftData
import Testing
@testable import Feature_BillingHub

@MainActor
@Suite(.tags(.integration))
struct BillingHubPhase2HonestyViewModelTests {
    @Test func supportLogSoftLockReturnsFalseWithoutSaving() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "LOCK-SL-001")
        let session = BillingHubPhase2HonestyFixtures.makeSession()
        session.invoice = invoice
        context.insert(invoice)
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
        let saved = try await viewModel.upsertSupportLog(sessionId: session.id, draft: draft)
        #expect(!saved)
        #expect(viewModel.pendingInvoicedSessionAction != nil)
        #expect(try context.fetch(FetchDescriptor<SupportLog>()).isEmpty)
    }

    @Test func savePaymentDraftReturnsFalseWhenInvoiceMissing() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let saved = await viewModel.savePaymentDraft(
            id: UUID(),
            amount: "10.00",
            date: Date(),
            method: "Bank Transfer",
            reference: "ref"
        )
        #expect(!(saved))
    }

    @Test func updateInvoiceDetailsReturnsFalseAndExplainsMissingInvoice() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = BillingHubViewModel(
            modelContext: context, modelContainer: container,
            ndisBillingIntegrationService: StubNDISBillingIntegrationService(
                response: Core.NDISBillingReport(
                    invoice: nil,
                    processedSessionsCount: 0,
                    successfulSessionsCount: 0,
                    failedSessions: [])
            )
        )

        let saved = await viewModel.updateInvoiceDetails(id: UUID(), clientName: "Client")

        #expect(!saved)
        #expect(viewModel.bulkActionFeedback == "Invoice could not be found.")
    }

    @Test func savePaymentDraftReturnsTrueOnSuccess() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "PAY-NOTE-001")
        invoice.status = .pending
        invoice.notes = nil
        context.insert(invoice)
        try context.save()

        let saved = await viewModel.savePaymentDraft(
            id: invoice.id,
            amount: "42.50",
            date: Date(),
            method: "Card",
            reference: "ABC"
        )
        #expect(saved)
        let refreshed = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
        #expect(refreshed.notes?.contains("42.50") == true)
        #expect(refreshed.status == Optional(.pending))
    }

    @Test func markOverdueAndBackMovesReturnBool() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "OVERDUE-001")
        invoice.status = .pending
        context.insert(invoice)
        try context.save()

        let overdue = await viewModel.markInvoiceOverdue(id: invoice.id)
        #expect(overdue)
        #expect(try context.fetch(FetchDescriptor<Invoice>()).first?.status == Optional(.overdue))

        let movedBack = await viewModel.moveInvoiceBackToReadyToSend(id: invoice.id)
        #expect(movedBack)
        #expect(try context.fetch(FetchDescriptor<Invoice>()).first?.status == Optional(.readyToSend))

        let missing = await viewModel.markInvoiceOverdue(id: UUID())
        #expect(!missing)
    }

    @Test func groupAndUngroupSoftLockWhenInvoiced() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "GRP-LOCK-001")
        let source = BillingHubPhase2HonestyFixtures.makeSession()
        source.invoice = invoice
        let target = BillingHubPhase2HonestyFixtures.makeSession()
        target.title = "Target"
        context.insert(invoice)
        context.insert(source)
        context.insert(target)
        try context.save()

        let grouped = await viewModel.groupSessionsSmooth(sourceID: source.id, targetID: target.id)
        #expect(!grouped)
        #expect(viewModel.pendingInvoicedSessionAction != nil)

        viewModel.cancelPendingInvoicedSessionAction()

        source.groupID = UUID()
        source.status = .grouped
        try context.save()
        let ungrouped = await viewModel.ungroupSession(id: source.id)
        #expect(!ungrouped)
        #expect(viewModel.pendingInvoicedSessionAction != nil)
    }


}
