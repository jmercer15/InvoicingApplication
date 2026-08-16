import Foundation
import Core
import PersistenceModels
import Data
import SwiftData
import Testing
@testable import Feature_BillingHub

@MainActor
@Suite(.tags(.integration))
struct BillingHubPhase2HonestyKanbanTests {
    @Test func nextColumnOnlyAllowsLegalForwardTransitions() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: StubNDISBillingIntegrationService(
                response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
            )
        )

        let completed = KanbanCardData.session(BillingHubPhase2HonestyFixtures.makeSessionCard(columnType: .completed))
        let grouped = KanbanCardData.session(BillingHubPhase2HonestyFixtures.makeSessionCard(columnType: .grouped))
        let addTravel = KanbanCardData.session(BillingHubPhase2HonestyFixtures.makeSessionCard(columnType: .addTravel))
        let review = KanbanCardData.invoice(BillingHubPhase2HonestyFixtures.makeInvoiceCard(columnType: .reviewDrafts))
        let ready = KanbanCardData.invoice(BillingHubPhase2HonestyFixtures.makeInvoiceCard(columnType: .readyToSend))
        let pending = KanbanCardData.invoice(BillingHubPhase2HonestyFixtures.makeInvoiceCard(columnType: .pending))
        let received = KanbanCardData.invoice(BillingHubPhase2HonestyFixtures.makeInvoiceCard(columnType: .received))

        #expect(viewModel.nextColumn(for: completed) == .grouped)
        #expect(viewModel.nextColumn(for: grouped) == nil, "grouped → addTravel must not be offered")
        #expect(viewModel.nextColumn(for: addTravel) == nil)
        #expect(viewModel.nextColumn(for: review) == .readyToSend)
        #expect(viewModel.nextColumn(for: ready) == .pending)
        #expect(viewModel.nextColumn(for: pending) == .received)
        #expect(viewModel.nextColumn(for: received) == nil)
    }

    @Test func dragDropCoordinatorRejectsSameColumnNoOpReorder() {
        let sessionID = UUID()
        let invoiceID = UUID()
        let projection = BillingHubBoardProjection(
            sessionsByStatus: [
                .completed: [.session(BillingHubPhase2HonestyFixtures.makeSessionCard(sessionID: sessionID, columnType: .completed))]
            ], invoicesByStatus: [
                .readyToSend: [.invoice(BillingHubPhase2HonestyFixtures.makeInvoiceCard(invoiceID: invoiceID, columnType: .readyToSend))]
            ],
            groupedSessions: [],
            clientSummaries: [])
        let coordinator = BillingHubDragDropCoordinator(projection: projection)

        #expect(!coordinator.canAcceptCardDrop(.session(sessionID), into: .completed, before: nil))
        #expect(!coordinator.canAcceptCardDrop(.invoice(invoiceID), into: .readyToSend, before: nil))
        #expect(coordinator.canAcceptCardDrop(.session(sessionID), into: .grouped, before: nil))
    }

    @Test func createDraftRejectsMixedClientSessionsBeforeNDIS() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let clientA = Client(id: UUID(), fullName: "Client A")
        let clientB = Client(id: UUID(), fullName: "Client B")
        let sessionA = BillingHubPhase2HonestyFixtures.makeSession()
        sessionA.client = clientA
        sessionA.status = .grouped
        let sessionB = BillingHubPhase2HonestyFixtures.makeSession()
        sessionB.client = clientB
        sessionB.status = .grouped

        context.insert(clientA)
        context.insert(clientB)
        context.insert(sessionA)
        context.insert(sessionB)
        try context.save()

        let refs = [
            SessionWorkflowReference(sessionID: sessionA.id, modelID: sessionA.persistentModelID),
            SessionWorkflowReference(sessionID: sessionB.id, modelID: sessionB.persistentModelID),
        ]
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(
                invoice: InvoiceSnapshot(Invoice(id: UUID(), invoiceNumber: "SHOULD-NOT-CREATE")),
                processedSessionsCount: 2,
                successfulSessionsCount: 2,
                failedSessions: [])
        )

        let report = try await workflow.createDraftInvoices(
            sessions: refs,
            clientID: clientA.id,
            ndisService: stub
        )

        // Only client A is eligible; mixed client B is failed before NDIS.
        // Stub may still be called for A-only set — assert B never succeeds.
        #expect(report.failedSessions.contains(where: {
            $0.sessionId == sessionB.id && $0.reason.localizedCaseInsensitiveContains("different client")
        }))
    }

    @Test func updateSessionDetailsParsesOneHourThirty() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)
        let start = Date()
        let session = BillingHubPhase2HonestyFixtures.makeSession()
        session.startTime = start
        session.endTime = start.addingTimeInterval(3600)
        context.insert(session)
        try context.save()

        try await workflow.updateSessionDetails(modelID: session.persistentModelID, durationString: "1h 30m")

        let refreshed = try #require(context.fetch(FetchDescriptor<Session>()).first)
        let end = try #require(refreshed.endTime)
        #expect(end.timeIntervalSince(start) == 90 * 60) // was accuracy: 1
    }

    @Test func undoLastBulkActionRestoresInvoiceSnapshot() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "UNDO-001")
        invoice.status = .readyToSend
        invoice.sentDate = nil
        invoice.paidDate = nil
        invoice.notes = "before"
        context.insert(invoice)
        try context.save()

        let projection = BillingHubBoardProjection(
            sessionsByStatus: [:],
            invoicesByStatus: [
                .readyToSend: [.invoice(BillingHubPhase2HonestyFixtures.makeInvoiceCard(invoiceID: invoice.id, columnType: .readyToSend))]
            ],
            groupedSessions: [],
            clientSummaries: []
        )

        await viewModel.markReadyToSendInvoicesSent(from: projection)
        #expect(viewModel.lastBulkUndoAction != nil)
        #expect(try context.fetch(FetchDescriptor<Invoice>()).first?.status == Optional(.pending))

        await viewModel.undoLastBulkAction()
        let restored = try #require(context.fetch(FetchDescriptor<Invoice>()).first)
        #expect(restored.status == Optional(.readyToSend))
        #expect(restored.sentDate == nil)
        #expect(restored.notes == "before")
        #expect(viewModel.lastBulkUndoAction == nil)
    }

    @Test func softLockStagesConfirmWhenSessionHasInvoice() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(invoice: nil, processedSessionsCount: 0, successfulSessionsCount: 0, failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let invoice = Invoice(id: UUID(), invoiceNumber: "LOCK-001")
        let session = BillingHubPhase2HonestyFixtures.makeSession()
        session.invoice = invoice
        context.insert(invoice)
        context.insert(session)
        try context.save()

        let result = await viewModel.moveSession(session.id, to: .grouped)
        #expect(result == nil)
        #expect(viewModel.pendingInvoicedSessionAction != nil)
        #expect(try context.fetch(FetchDescriptor<Session>()).first?.status == Optional(.completed))
    }

    @Test func successfulMovesNameDestinationLaneInFeedback() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let stub = StubNDISBillingIntegrationService(
            response: Core.NDISBillingReport(
                invoice: nil, processedSessionsCount: 0,
                successfulSessionsCount: 0,
                failedSessions: [])
        )
        let viewModel = BillingHubViewModel(
            modelContext: context,
            modelContainer: container,
            ndisBillingIntegrationService: stub
        )

        let session = BillingHubPhase2HonestyFixtures.makeSession()
        session.status = .completed
        let invoice = Invoice(id: UUID(), invoiceNumber: "MOVE-COPY-001")
        invoice.status = .reviewDraft
        context.insert(session)
        context.insert(invoice)
        try context.save()

        let sessionResult = await viewModel.moveSession(session.id, to: .grouped)
        #expect(sessionResult?.isSuccess == true)
        #expect(viewModel.bulkActionFeedback == "Session moved to Grouped.")

        let invoiceResult = await viewModel.moveInvoice(invoice.id, to: .readyToSend)
        #expect(invoiceResult?.isSuccess == true)
        #expect(viewModel.bulkActionFeedback == "Invoice moved to Ready to Send.")
    }


}
