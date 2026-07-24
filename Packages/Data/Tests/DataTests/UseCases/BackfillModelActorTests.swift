import Core
import SwiftData
@testable import Data
import XCTest

@MainActor
final class BackfillModelActorTests: XCTestCase {
    func testBackfillCompletesBeforeStatusTokenQueriesRun() async throws {
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

        let refreshedSession = try XCTUnwrap(context.fetch(FetchDescriptor<Session>()).first)
        let refreshedInvoice = try XCTUnwrap(context.fetch(FetchDescriptor<Invoice>()).first)
        XCTAssertEqual(refreshedSession.statusToken, SessionStatus.completed.rawValue)
        XCTAssertEqual(refreshedInvoice.statusToken, InvoiceStatus.readyToSend.rawValue)
    }
}
