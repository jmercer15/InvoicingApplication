import Core
import PersistenceModels
import Data
import Foundation
import SwiftData
import Testing
import CoreTesting
@testable import Feature_BillingHub

@Suite(.tags(.integration))
struct BillingHubWorkflowActorTests {
    @Test @MainActor
    func fetchProjectionFiltersCompletedSessionsAndReviewDraftInvoices() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let completedSession = Session(id: UUID(), title: "Done")
        completedSession.status = SessionStatus.completed
        completedSession.startTime = Date()
        context.insert(completedSession)

        let draftSession = Session(id: UUID(), title: "Draft")
        draftSession.status = SessionStatus.scheduled
        draftSession.startTime = Date()
        context.insert(draftSession)

        let reviewInvoice = Invoice(id: UUID(), invoiceNumber: "INV-1")
        reviewInvoice.status = .reviewDraft
        context.insert(reviewInvoice)

        let pendingInvoice = Invoice(id: UUID(), invoiceNumber: "INV-2")
        pendingInvoice.status = .pending
        context.insert(pendingInvoice)

        try context.save()

        let projection = try await workflow.fetchProjection(
            searchText: "",
            selectedClientID: nil,
            sortOptions: [:]
        )

        let completedCards = projection.sessionsByStatus[.completed] ?? []
        let reviewCards = projection.invoicesByStatus[.reviewDrafts] ?? []

        #expect(completedCards.contains(where: { $0.id == completedSession.id }))
        #expect(completedCards.contains(where: { $0.id == draftSession.id }) == false)
        #expect(reviewCards.contains(where: { $0.id == reviewInvoice.id }))
        #expect(reviewCards.contains(where: { $0.id == pendingInvoice.id }) == false)
    }

    @Test @MainActor
    func moveInvoiceRejectsInvalidTransition() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-3")
        invoice.status = .reviewDraft
        context.insert(invoice)
        try context.save()

        let result = try await workflow.moveInvoice(
            modelID: invoice.persistentModelID, to: .received)

        if case .invalidTransition(from: BillingStatus.reviewDrafts.rawValue, to: KanbanCardData.BillingColumnType.received.rawValue) = result {
            return
        }
        Issue.record("Expected invalidTransition, got \(result)")
    }

    @Test @MainActor
    func approveDraftInvoicePersistsDueDateAndStatusTogether() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-4")
        invoice.status = .reviewDraft
        context.insert(invoice)
        try context.save()

        let dueDate = Date(timeIntervalSince1970: 1_750_000_000)
        let result = try await workflow.approveDraftInvoice(
            modelID: invoice.persistentModelID,
            dueDate: dueDate
        )

        #expect(result == .success)

        let refreshed = try context.fetch(FetchDescriptor<Invoice>()).first { $0.id == invoice.id }
        #expect(refreshed?.status == .readyToSend)
        #expect(refreshed?.dueDate == dueDate)
    }

    @Test @MainActor
    func updateSessionDetailsParsesDurationAndPersistsEndTime() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let session = Session(id: UUID(), title: "Timed")
        session.startTime = start
        session.status = SessionStatus.completed
        context.insert(session)
        try context.save()

        try await workflow.updateSessionDetails(
            modelID: session.persistentModelID, durationString: "90m")

        let refreshed = try context.fetch(FetchDescriptor<Session>()).first { $0.id == session.id }
        let expectedEnd = Calendar.current.date(byAdding: .minute, value: 90, to: start)
        #expect(refreshed?.endTime == expectedEnd)
    }

    @Test @MainActor
    func sessionWorkflowReferencesForGroupReturnsSortedMembers() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let workflow = BillingHubWorkflowActor(modelContainer: container)
        let groupID = UUID()

        let later = Session(id: UUID(), title: "Later")
        later.groupID = groupID
        later.startTime = Date(timeIntervalSince1970: 2_000)
        later.status = SessionStatus.grouped

        let earlier = Session(id: UUID(), title: "Earlier")
        earlier.groupID = groupID
        earlier.startTime = Date(timeIntervalSince1970: 1_000)
        earlier.status = SessionStatus.grouped

        context.insert(later)
        context.insert(earlier)
        try context.save()

        let refs = try await workflow.sessionWorkflowReferencesForGroup(groupID: groupID)

        #expect(refs.count == 2)
        #expect(refs.map(\.sessionID) == [earlier.id, later.id])
    }
}
