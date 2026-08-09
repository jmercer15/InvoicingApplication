import Core
import SwiftData
@testable import Data
import Testing
import PersistenceModels
@MainActor
@Suite struct BackfillModelActorTests {
    @Test func BackfillCompletesBeforeStatusTokenQueriesRun() async throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let session = Session(title: "Completed session", status: .completed)
        session.statusToken = ""
        let invoice = Invoice(invoiceNumber: "INV-BACKFILL")
        invoice.status = .readyToSend
        invoice.statusToken = ""
        context.insert(session)
        context.insert(invoice)
        try context.save()

        let actor = BackfillModelActor(modelContainer: container)
        try await actor.backfillStatusTokensIfNeeded()

        let refreshedSession = try try #require(context.fetch(FetchDescriptor<Session>()).first)
        let refreshedInvoice = try try #require(context.fetch(FetchDescriptor<Invoice>()).first)
        #expect(refreshedSession.statusToken == SessionStatus.completed.rawValue)
        #expect(refreshedInvoice.statusToken == InvoiceStatus.readyToSend.rawValue)
    }
}
