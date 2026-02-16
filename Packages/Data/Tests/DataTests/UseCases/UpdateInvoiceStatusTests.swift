import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class UpdateInvoiceStatusTests: XCTestCase {
    private var modelContext: ModelContext!
    private var repository: InvoicesRepositorySwiftData!
    private var updateInvoiceStatus: UpdateInvoiceStatus!

    override func setUp() async throws {
        try await super.setUp()

        let models: [any PersistentModel.Type] = [
            AddressEntity.self,
            InvoiceEntity.self,
            ClientEntity.self,
            BusinessEntity.self,
            PayeeEntity.self,
            SessionEntity.self,
            InvoiceItemEntity.self
        ]
        let (_, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
        modelContext = context

        repository = InvoicesRepositorySwiftData(modelContext: modelContext)
        updateInvoiceStatus = UpdateInvoiceStatus(repository: repository)
    }

    override func tearDown() async throws {
        modelContext = nil
        repository = nil
        updateInvoiceStatus = nil
        try await super.tearDown()
    }

    func testUpdateStatus_AcceptsCanonicalTokenAndSetsSentDate() async throws {
        let invoice = try insertInvoice(status: .reviewDraft)

        let updated = try await updateInvoiceStatus(id: invoice.id, status: InvoiceStatus.pending.rawValue)

        XCTAssertEqual(updated.status, InvoiceStatus.pending.rawValue)
        XCTAssertNotNil(updated.sentDate)
    }

    func testUpdateStatus_PendingKeepsExistingSentDate() async throws {
        let originalSentDate = Date(timeIntervalSince1970: 1_715_000_000)
        let invoice = try insertInvoice(status: .pending, sentDate: originalSentDate)

        let updated = try await updateInvoiceStatus(id: invoice.id, status: InvoiceStatus.pending.rawValue)

        XCTAssertEqual(updated.status, InvoiceStatus.pending.rawValue)
        XCTAssertEqual(updated.sentDate, originalSentDate)
        XCTAssertNil(updated.paidDate)
    }

    func testUpdateStatus_MoveBackToReadyToSendClearsLifecycleDates() async throws {
        let invoice = try insertInvoice(
            status: .received,
            sentDate: Date(timeIntervalSince1970: 1_715_000_000),
            paidDate: Date(timeIntervalSince1970: 1_716_000_000)
        )

        let updated = try await updateInvoiceStatus(id: invoice.id, status: InvoiceStatus.readyToSend.rawValue)

        XCTAssertEqual(updated.status, InvoiceStatus.readyToSend.rawValue)
        XCTAssertNil(updated.sentDate)
        XCTAssertNil(updated.paidDate)
    }

    func testUpdateStatus_RejectsNonCanonicalToken() async throws {
        let invoice = try insertInvoice(status: .reviewDraft)
        do {
            _ = try await updateInvoiceStatus(id: invoice.id, status: "PENDING")
            XCTFail("Expected updateInvoiceStatus to reject non-canonical status")
        } catch { }
    }

    func testMarkAsPaid_SetsPaidDate() async throws {
        let invoice = try insertInvoice(status: .pending)

        let updated = try await updateInvoiceStatus(markAsPaid: invoice.id)

        XCTAssertEqual(updated.status, InvoiceStatus.received.rawValue)
        XCTAssertNotNil(updated.paidDate)
    }

    func testUpdateBillingStatus_MapsPendingToPending() async throws {
        let invoice = try insertInvoice(status: .reviewDraft)

        let updated = try await updateInvoiceStatus(id: invoice.id, billingStatus: .pending)

        XCTAssertEqual(updated.status, InvoiceStatus.pending.rawValue)
        XCTAssertNotNil(updated.sentDate)
    }

    func testUpdateBillingStatus_MapsReceivedToReceived() async throws {
        let invoice = try insertInvoice(status: .pending)

        let updated = try await updateInvoiceStatus(id: invoice.id, billingStatus: .received)

        XCTAssertEqual(updated.status, InvoiceStatus.received.rawValue)
        XCTAssertNotNil(updated.paidDate)
    }

    func testUpdateStatus_SyncsLinkedSessionToPending() async throws {
        let session = try insertSession(status: .reviewDraft)
        let invoice = try insertInvoice(status: .readyToSend, sessions: [session])

        _ = try await updateInvoiceStatus(id: invoice.id, status: InvoiceStatus.pending.rawValue)

        let refreshedSession = try fetchSession(id: session.id)
        XCTAssertEqual(refreshedSession?.status, .pending)
    }

    func testUpdateStatus_SyncsLinkedSessionToReceived() async throws {
        let session = try insertSession(status: .pending)
        let invoice = try insertInvoice(status: .pending, sessions: [session])

        _ = try await updateInvoiceStatus(id: invoice.id, status: InvoiceStatus.received.rawValue)

        let refreshedSession = try fetchSession(id: session.id)
        XCTAssertEqual(refreshedSession?.status, .received)
    }

    func testCreateFromSessions_SyncsLinkedSessionToReviewDraft() async throws {
        let session = try insertSession(status: .completed)

        let created = try await repository.createFromSessions([session.id], clientId: UUID())

        XCTAssertEqual(created.status, InvoiceStatus.reviewDraft.rawValue)
        let refreshedSession = try fetchSession(id: session.id)
        XCTAssertEqual(refreshedSession?.status, .reviewDraft)
    }

    func testUpdateInvoice_SyncsLinkedSessionToReadyToSend() async throws {
        let session = try insertSession(status: .reviewDraft)
        let invoiceEntity = try insertInvoice(status: .reviewDraft, sessions: [session])

        guard var fetched = try await repository.fetch(by: invoiceEntity.id) else {
            XCTFail("Expected to fetch created invoice")
            return
        }
        fetched.status = InvoiceStatus.readyToSend.rawValue

        _ = try await repository.update(fetched)

        let refreshedSession = try fetchSession(id: session.id)
        XCTAssertEqual(refreshedSession?.status, .readyToSend)
    }

    func testUpdateInvoice_BackwardStatusClearsLifecycleDates() async throws {
        let invoiceEntity = try insertInvoice(
            status: .received,
            sentDate: Date(timeIntervalSince1970: 1_715_000_000),
            paidDate: Date(timeIntervalSince1970: 1_716_000_000)
        )

        guard var fetched = try await repository.fetch(by: invoiceEntity.id) else {
            XCTFail("Expected to fetch created invoice")
            return
        }
        fetched.status = InvoiceStatus.reviewDraft.rawValue

        let updated = try await repository.update(fetched)

        XCTAssertEqual(updated.status, InvoiceStatus.reviewDraft.rawValue)
        XCTAssertNil(updated.sentDate)
        XCTAssertNil(updated.paidDate)
    }

    func testMarkAsSent_PreservesInvoiceTotals() async throws {
        let originalTotal = 1234.56
        let invoice = try insertInvoice(status: .reviewDraft, totalAmount: originalTotal)

        let updated = try await updateInvoiceStatus(markAsSent: invoice.id)

        XCTAssertEqual(updated.status, InvoiceStatus.pending.rawValue)
        XCTAssertEqual(updated.totalAmount, originalTotal)
    }

    func testRepositoryFetchByStatus_RequiresCanonicalStatusToken() async throws {
        _ = try insertInvoice(status: .pending)
        do {
            let _: [Invoice] = try await repository.fetch(by: "PENDING")
            XCTFail("Expected fetch(by:) to reject non-canonical status token")
        } catch { }
    }

    @discardableResult
    private func insertInvoice(
        status: InvoiceStatus,
        totalAmount: Double = 1000.0,
        sessions: [SessionEntity] = [],
        sentDate: Date? = nil,
        paidDate: Date? = nil
    ) throws -> InvoiceEntity {
        let entity = InvoiceEntity(id: UUID(), invoiceNumber: "INV-TEST-\(UUID().uuidString.prefix(8))")
        entity.date = Date()
        entity.issueDate = entity.date
        entity.dueDate = Calendar.current.date(byAdding: .day, value: 30, to: entity.date)
        entity.totalAmount = totalAmount
        entity.currencyCode = "AUD"
        entity.status = status
        entity.sentDate = sentDate
        entity.paidDate = paidDate
        entity.clientName = "Test Client"
        entity.businessName = "Test Business"
        entity.sessions = sessions

        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertSession(status: SessionStatus) throws -> SessionEntity {
        let entity = SessionEntity(id: UUID())
        entity.title = "Test Session"
        entity.status = status
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func fetchSession(id: UUID) throws -> SessionEntity? {
        let predicate = #Predicate<SessionEntity> { $0.id == id }
        let descriptor = FetchDescriptor<SessionEntity>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
}
