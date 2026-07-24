import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class NDISComplianceValidatorTests: XCTestCase {
    private typealias PersistenceNDISClaimType = NDISClaimType

    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var validator: NDISComplianceValidator!

    override func setUp() async throws {
        try await super.setUp()

        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context

        validator = NDISComplianceValidator(modelContainer: modelContainer)
    }

    override func tearDown() async throws {
        validator = nil
        modelContext = nil
        modelContainer = nil
        try await super.tearDown()
    }

    func testMissingBusinessBlocksInvoiceTransition() async throws {
        let invoice = try insertInvoice(session: nil, claimType: nil, gstCode: nil)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice,
            targetStatus: nil
        )

        XCTAssertTrue(result.blockers.contains { $0.id == "business.missing" })
    }

    func testInvalidABNBlocksInvoiceTransition() async throws {
        _ = try insertBusiness(abn: "123", isRegisteredProvider: true)
        let invoice = try insertInvoice(session: nil, claimType: nil, gstCode: nil)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice,
            targetStatus: nil
        )

        XCTAssertTrue(result.blockers.contains { $0.id == "business.abn.invalid" })
    }

    func testNonRegisteredProviderProducesWarning() async throws {
        _ = try insertBusiness(abn: "53004085616", isRegisteredProvider: false)
        let invoice = try insertInvoice(session: nil, claimType: nil, gstCode: nil)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice,
            targetStatus: nil
        )

        XCTAssertTrue(result.warnings.contains { $0.id == "business.ndis_provider.not_registered" })
        XCTAssertTrue(result.blockers.contains { $0.id == "invoice.items.empty" })
    }

    func testMissingServiceAgreementBlocksWhenSessionLinked() async throws {
        _ = try insertBusiness()
        let client = try insertClient()
        let session = try insertSession(client: client)
        let invoice = try insertInvoice(session: session, claimType: .direct, gstCode: GSTCode.p2.rawValue)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice,
            targetStatus: nil
        )

        XCTAssertTrue(result.blockers.contains { $0.id == "agreement.missing" })
    }

    func testTelehealthDisallowedByAgreementBlocks() async throws {
        _ = try insertBusiness()
        let client = try insertClient()
        _ = try insertServiceAgreement(client: client, allowsTelehealth: false)
        let session = try insertSession(client: client)
        let invoice = try insertInvoice(session: session, claimType: .telehealth, gstCode: GSTCode.p2.rawValue)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice,
            targetStatus: nil
        )

        XCTAssertTrue(result.blockers.contains { $0.id == "agreement.telehealth.disallowed" })
    }

    func testMissingSupportLogProducesWarningForSessionValidation() async throws {
        _ = try insertBusiness()
        let client = try insertClient()
        _ = try insertServiceAgreement(client: client, allowsTelehealth: true)
        let session = try insertSession(client: client)

        let result = try await validator.validateSessionForInvoicing(sessionId: session.id)

        XCTAssertTrue(result.warnings.contains { $0.id == "support_log.missing" })
        XCTAssertTrue(result.blockers.isEmpty)
    }

    func testInvalidInvoiceItemGSTProducesWarningOnly() async throws {
        _ = try insertBusiness()
        let client = try insertClient()
        _ = try insertServiceAgreement(client: client, allowsTelehealth: true)
        let session = try insertSession(client: client)
        _ = try insertSupportLog(client: client, session: session)
        let invoice = try insertInvoice(session: session, claimType: .direct, gstCode: "ZZ_INVALID")

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice,
            targetStatus: nil
        )

        XCTAssertTrue(result.warnings.contains { $0.id == "invoice_item.gst.invalid" })
    }

    func testBulkValidationReturnsPerInvoiceResults() async throws {
        _ = try insertBusiness()
        let client = try insertClient()
        _ = try insertServiceAgreement(client: client, allowsTelehealth: true)
        let session = try insertSession(client: client)
        _ = try insertSupportLog(client: client, session: session)

        let good = try insertInvoice(session: session, claimType: .direct, gstCode: GSTCode.p2.rawValue)
        let empty = try insertInvoice(session: nil, claimType: nil, gstCode: nil)

        let results = try await validator.validateBulkInvoices(
            invoiceIds: [good.id, empty.id],
            action: .bulkSendReady
        )

        XCTAssertEqual(results.count, 2)
        XCTAssertFalse(results[good.id]?.isBlocked ?? true)
        XCTAssertTrue(results[empty.id]?.blockers.contains { $0.id == "invoice.items.empty" } ?? false)
    }

    // MARK: - Fixtures

    @discardableResult
    private func insertBusiness(
        abn: String = "53004085616",
        isRegisteredProvider: Bool = true
    ) throws -> Business {
        let entity = Business(id: UUID(), abn: abn)
        entity.name = "Test Business"
        entity.defaultGstCode = GSTCode.p2.rawValue
        entity.isRegisteredProvider = isRegisteredProvider
        entity.ndiaOrganisationID = "ORG123"
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertClient() throws -> Client {
        let entity = Client(
            id: UUID(),
            ndisNumber: "4300123456",
            fullName: "Test Client",
            status: .active
        )
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertSession(client: Client) throws -> Session {
        let entity = Session(id: UUID())
        entity.title = "Support Session"
        entity.startTime = Date().addingTimeInterval(-3_600)
        entity.endTime = Date()
        entity.status = .completed
        entity.client = client
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertServiceAgreement(
        client: Client,
        allowsTelehealth: Bool,
        allowsNonFaceToFace: Bool = true,
        allowsProviderTravel: Bool = true
    ) throws -> ServiceAgreement {
        let entity = ServiceAgreement(id: UUID())
        entity.client = client
        entity.effectiveFrom = Date().addingTimeInterval(-86_400)
        entity.effectiveTo = Date().addingTimeInterval(86_400 * 365)
        entity.cancellationPolicyType = CancellationPolicyType.twoClearBusinessDays.rawValue
        entity.allowsTelehealth = allowsTelehealth
        entity.allowsNonFaceToFace = allowsNonFaceToFace
        entity.allowsProviderTravel = allowsProviderTravel
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertSupportLog(client: Client, session: Session) throws -> SupportLog {
        let entity = SupportLog(id: UUID())
        entity.client = client
        entity.session = session
        entity.participantName = client.fullName
        entity.participantNdisNumber = client.ndisNumber
        entity.supportItemNumber = "01_011_0107_1_1"
        entity.serviceDescription = "Daily Living Support"
        entity.location = "Home"
        entity.deliveredFrom = session.startTime ?? Date().addingTimeInterval(-3_600)
        entity.deliveredTo = session.endTime ?? Date()
        entity.quantityHours = 1.0
        entity.deliveredBy = "Support Worker"
        entity.attestedBy = "Participant"
        entity.attestedAt = Date()
        entity.signatureMethod = SignatureMethod.attestation.rawValue
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertInvoice(
        session: Session?,
        claimType: PersistenceNDISClaimType?,
        gstCode: String?
    ) throws -> Invoice {
        let invoice = Invoice(
            id: UUID(),
            invoiceNumber: "INV-\(UUID().uuidString.prefix(8))"
        )
        invoice.date = Date()
        invoice.issueDate = invoice.date
        invoice.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: invoice.date)
        invoice.status = .readyToSend

        if let session {
            invoice.sessions = [session]
            session.invoice = invoice
        }

        modelContext.insert(invoice)

        if let claimType {
            let item = InvoiceItem(id: UUID(), itemDescription: "NDIS Support")
            item.invoice = invoice
            item.session = session
            item.claimType = claimType
            item.rate = 100
            item.quantity = 1
            item.gstCode = gstCode
            modelContext.insert(item)
            invoice.items = (invoice.items ?? []) + [item]
        }

        try modelContext.save()
        return invoice
    }

    func testExportValidation_blocksMissingSupportItemCode() async throws {
        let business = try insertBusiness(abn: "53004085616", isRegisteredProvider: true)
        business.bankAccountName = "Provider Account"
        business.bankBSB = "123456"
        business.bankAccountNumber = "987654321"
        try modelContext.save()

        let client = try insertClient()
        let invoice = try insertInvoice(session: nil, claimType: .direct, gstCode: GSTCode.p2.rawValue)
        invoice.client = client
        invoice.clientNDISNumber = client.ndisNumber
        invoice.bankAccountName = business.bankAccountName
        invoice.bankBSB = business.bankBSB
        invoice.bankAccountNumber = business.bankAccountNumber
        if let item = invoice.items?.first {
            item.ndisItemNumber = nil
            item.serviceDate = Date(timeIntervalSince1970: 1_704_067_200)
        }
        try modelContext.save()

        let snapshot = try XCTUnwrap(try modelContext.fetch(FetchDescriptor<Invoice>()).first?.snapshot())
        let items = try modelContext.fetch(FetchDescriptor<InvoiceItem>()).map { $0.snapshot() }

        let result = validator.validateInvoiceForExport(
            invoice: snapshot,
            items: items,
            business: business.snapshot(),
            strict: true
        )

        XCTAssertTrue(result.blockers.contains { $0.id == "invoice_item.support_item_code.missing" })
    }

    func testExportValidation_blocksPAPLRateExceeded() async throws {
        let business = try insertBusiness(abn: "53004085616", isRegisteredProvider: true)
        business.bankAccountName = "Provider Account"
        business.bankBSB = "123456"
        business.bankAccountNumber = "987654321"
        try modelContext.save()

        let client = try insertClient()
        let invoice = try insertInvoice(session: nil, claimType: .direct, gstCode: GSTCode.p2.rawValue)
        invoice.client = client
        invoice.clientNDISNumber = client.ndisNumber
        invoice.bankAccountName = business.bankAccountName
        invoice.bankBSB = business.bankBSB
        invoice.bankAccountNumber = business.bankAccountNumber
        if let item = invoice.items?.first {
            item.ndisItemNumber = "01_011_0107_1_1"
            item.serviceDate = Date(timeIntervalSince1970: 1_704_067_200)
            item.rate = 120
            item.finalRateLimit = 100
        }
        try modelContext.save()

        let snapshot = try XCTUnwrap(try modelContext.fetch(FetchDescriptor<Invoice>()).first?.snapshot())
        let items = try modelContext.fetch(FetchDescriptor<InvoiceItem>()).map { $0.snapshot() }

        let result = validator.validateInvoiceForExport(
            invoice: snapshot,
            items: items,
            business: business.snapshot(),
            strict: true
        )

        XCTAssertTrue(result.blockers.contains { $0.id == "invoice_item.papl_rate_exceeded" })
    }
}
