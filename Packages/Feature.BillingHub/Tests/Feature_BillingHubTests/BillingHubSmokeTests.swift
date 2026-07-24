import Foundation
import Core
import Data
import SwiftData
import SwiftUI
import XCTest
@testable import Feature_BillingHub

@MainActor
final class BillingHubFeatureSmokeTests: XCTestCase {
    func testDragDropCoordinatorValidatesSessionAndInvoiceMoves() {
        let sourceSessionID = UUID()
        let targetSessionID = UUID()
        let sourceInvoiceID = UUID()

        let projection = BillingHubBoardProjection(
            sessionsByStatus: [
                .completed: [
                    .session(makeSessionCard(sessionID: sourceSessionID, columnType: .completed))
                ],
                .grouped: [
                    .session(makeSessionCard(sessionID: targetSessionID, columnType: .grouped))
                ]
            ],
            invoicesByStatus: [
                .reviewDrafts: [
                    .invoice(makeInvoiceCard(invoiceID: sourceInvoiceID, columnType: .reviewDrafts))
                ],
                .readyToSend: [
                    .invoice(makeInvoiceCard(invoiceID: UUID(), columnType: .readyToSend))
                ]
            ],
            groupedSessions: [],
            clientSummaries: []
        )
        let coordinator = BillingHubDragDropCoordinator(projection: projection)

        XCTAssertTrue(coordinator.canAcceptCardDrop(.session(sourceSessionID), into: .grouped, before: nil))
        XCTAssertFalse(coordinator.canAcceptCardDrop(.session(sourceSessionID), into: .readyToSend, before: nil))
        XCTAssertFalse(coordinator.canAcceptCardDrop(.session(sourceSessionID), into: .grouped, before: sourceSessionID))
        XCTAssertTrue(coordinator.canAcceptCardDrop(.invoice(sourceInvoiceID), into: .readyToSend, before: nil))
        XCTAssertFalse(coordinator.canAcceptCardDrop(.invoice(sourceInvoiceID), into: .pending, before: nil))
    }

    func testWorkflowActorCompletesSessionMoveAndPersistsStatus() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let session = makeSession()
        context.insert(session)
        try context.save()

        let result = try await workflow.moveSession(
            modelID: session.persistentModelID,
            to: .grouped
        )
        XCTAssertEqual(result, .success)

        let updated = try context.fetch(FetchDescriptor<Session>()).first { $0.persistentModelID == session.persistentModelID }
        XCTAssertEqual(updated?.status, Optional(.grouped))
    }

    func testWorkflowActorReturnsNotFoundForDeletedSessionModelID() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)
        let session = makeSession()
        context.insert(session)
        try context.save()
        let deletedModelID = session.persistentModelID
        context.delete(session)
        try context.save()

        let result = try await workflow.moveSession(
            modelID: deletedModelID,
            to: .grouped
        )

        XCTAssertEqual(result, .notFound)
    }

    func testWorkflowActorBulkUpdateInvoiceOperationHandlesLargeBatch() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let total = 120
        let invoices = (0..<total).map { index in
            let invoice = makeInvoice(index: index, status: .readyToSend)
            context.insert(invoice)
            return invoice
        }
        try context.save()
        let invoiceModelIDs = invoices.map(\.persistentModelID)

        let processed = try await workflow.bulkUpdateInvoices(
            modelIDs: invoiceModelIDs,
            targetStatus: .received
        ) { invoice in
            if invoice.paidDate == nil { invoice.paidDate = Date() }
        }
        XCTAssertEqual(processed, total)

        let refreshedInvoices = try context.fetch(FetchDescriptor<Invoice>())
        XCTAssertEqual(refreshedInvoices.count, total)
        XCTAssertTrue(refreshedInvoices.allSatisfy { $0.effectiveStatus == .received })
        XCTAssertTrue(refreshedInvoices.allSatisfy { $0.invoiceEditorRevision == 1 })
    }

    func testWorkflowActorInvoiceMetadataEditInvalidatesOpenEditorDraft() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)
        let invoice = makeInvoice(index: 1, status: .reviewDraft)
        context.insert(invoice)
        try context.save()

        try await workflow.updateInvoiceDetails(
            modelID: invoice.persistentModelID,
            clientName: "Updated Client"
        )

        let refreshed = try XCTUnwrap(context.fetch(FetchDescriptor<Invoice>()).first)
        XCTAssertEqual(refreshed.clientName, "Updated Client")
        XCTAssertEqual(refreshed.invoiceEditorRevision, 1)
        XCTAssertEqual(refreshed.totalAmount, 1)

        try await workflow.updateInvoiceDetails(
            modelID: invoice.persistentModelID,
            clientName: "Updated Client"
        )
        XCTAssertEqual(refreshed.invoiceEditorRevision, 1)
    }

    private func makeSession() -> Session {
        let session = Session(id: UUID())
        session.title = "Smoke Session"
        session.status = .completed
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        return session
    }

    private func makeSessionCard(
        sessionID: UUID,
        columnType: KanbanCardData.BillingColumnType
    ) -> SessionKanbanCardData {
        SessionKanbanCardData(
            sessionId: sessionID,
            title: "Session",
            clientName: "Client",
            serviceName: "Service",
            travelRate: nil,
            travelRateUnit: nil,
            suggestedTravelDistanceKM: nil,
            suggestedTravelTimeMinutes: nil,
            priority: .low,
            accentColor: .blue,
            duration: "60m",
            date: "today",
            hasIssues: false,
            workflowStatus: .readyToInvoice,
            columnType: columnType,
            startTime: Date(),
            endTime: Date(),
            groupID: nil
        )
    }

    private func makeInvoiceCard(
        invoiceID: UUID,
        columnType: KanbanCardData.BillingColumnType
    ) -> InvoiceKanbanCardData {
        InvoiceKanbanCardData(
            invoiceId: invoiceID,
            title: "Invoice",
            clientName: "Client",
            serviceName: "Service",
            priority: .medium,
            accentColor: .green,
            amount: "$100.00",
            date: "today",
            workflowStatus: .draftReview,
            columnType: columnType,
            isOverdue: false,
            daysOverdue: nil,
            rawDate: Date()
        )
    }

    private func makeInvoice(index: Int, status: InvoiceStatus) -> Invoice {
        let invoice = Invoice(id: UUID(), invoiceNumber: String(format: "INV-%03d", index))
        invoice.clientName = "Client \(index % 3)"
        invoice.issueDate = Date(timeIntervalSince1970: Double(index))
        invoice.date = Date(timeIntervalSince1970: Double(index))
        invoice.dueDate = Date(timeIntervalSince1970: Double(index)).addingTimeInterval(86_400)
        invoice.totalAmount = Double(index)
        invoice.status = status
        return invoice
    }
}
