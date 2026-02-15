import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class NDISComplianceValidatorTests: XCTestCase {
    private var modelContext: ModelContext!
    private var validator: NDISComplianceValidator!

    override func setUp() async throws {
        try await super.setUp()

        let schema = Schema([
            ClientEntity.self,
            BusinessEntity.self,
            AddressEntity.self,
            InvoiceEntity.self,
            InvoiceItemEntity.self,
            ClientServiceEntity.self,
            PayeeEntity.self,
            PlanManagerEntity.self,
            SessionEntity.self,
            TravelChargeEntity.self,
            TravelChargeAuditLogEntity.self,
            TravelChargeReviewItemEntity.self,
            CreditHistoryEntryEntity.self,
            NDISItemEntity.self,
            RegionalPriceEntity.self,
            ServiceAgreementEntity.self,
            SupportLogEntity.self,
            BulkClaimBatchEntity.self,
            BulkClaimLineEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        modelContext = ModelContext(container)

        let businessRepository = BusinessRepositorySwiftData(modelContext: modelContext)
        let invoicesRepository = InvoicesRepositorySwiftData(modelContext: modelContext)
        let sessionsRepository = SessionsRepositorySwiftData(modelContext: modelContext)
        let serviceAgreementRepository = ServiceAgreementRepositorySwiftData(modelContext: modelContext)
        let supportLogRepository = SupportLogRepositorySwiftData(modelContext: modelContext)

        validator = NDISComplianceValidator(
            businessRepository: businessRepository,
            invoicesRepository: invoicesRepository,
            sessionsRepository: sessionsRepository,
            serviceAgreementRepository: serviceAgreementRepository,
            supportLogRepository: supportLogRepository
        )
    }

    override func tearDown() async throws {
        validator = nil
        modelContext = nil
        try await super.tearDown()
    }

    func testRegisteredProviderMissingOrgIdBlocksTransition() async throws {
        try insertBusiness(isRegisteredProvider: true, ndiaOrganisationID: nil)
        let invoice = try insertInvoice()

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice
        )

        XCTAssertTrue(result.blockers.contains(where: { $0.id == "BUS-ORG-001" }))
    }

    func testMissingServiceAgreementBlocksTransition() async throws {
        try insertBusiness()
        let client = try insertClient()
        let session = try insertSession(client: client)
        _ = try insertSupportLog(client: client, session: session)
        let invoice = try insertInvoice(session: session, claimType: .direct, gstCode: GSTCode.p2.rawValue)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice
        )

        XCTAssertTrue(result.blockers.contains(where: { $0.id == "AGR-ACT-001" }))
    }

    func testMissingSupportLogBlocksTransition() async throws {
        try insertBusiness()
        let client = try insertClient()
        let session = try insertSession(client: client)
        _ = try insertServiceAgreement(client: client, allowsTelehealth: true, allowsNonFaceToFace: true, allowsProviderTravel: true)
        let invoice = try insertInvoice(session: session, claimType: .direct, gstCode: GSTCode.p2.rawValue)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice
        )

        XCTAssertTrue(result.blockers.contains(where: { $0.id == "LOG-REQ-001" }))
    }

    func testTelehealthClaimDisallowedByAgreementBlocksTransition() async throws {
        try insertBusiness()
        let client = try insertClient()
        let session = try insertSession(client: client)
        _ = try insertServiceAgreement(client: client, allowsTelehealth: false, allowsNonFaceToFace: true, allowsProviderTravel: true)
        _ = try insertSupportLog(client: client, session: session)
        let invoice = try insertInvoice(session: session, claimType: .telehealth, gstCode: GSTCode.p2.rawValue)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice
        )

        XCTAssertTrue(result.blockers.contains(where: { $0.id == "AGR-AUTH-THLT" }))
    }

    func testMissingLineGSTProducesWarningOnly() async throws {
        try insertBusiness()
        let invoice = try insertInvoice(claimType: .direct, gstCode: nil)

        let result = try await validator.validateInvoiceTransition(
            invoiceId: invoice.id,
            action: .sendInvoice
        )

        XCTAssertTrue(result.blockers.isEmpty)
        XCTAssertTrue(result.warnings.contains(where: { $0.id == "GST-LINE-001" }))
    }

    func testBulkValidationReturnsMixedPassFailResults() async throws {
        try insertBusiness()

        let passingInvoice = try insertInvoice()

        let client = try insertClient()
        let blockedSession = try insertSession(client: client)
        _ = try insertSupportLog(client: client, session: blockedSession)
        let blockedInvoice = try insertInvoice(session: blockedSession, claimType: .direct, gstCode: GSTCode.p2.rawValue)

        let results = try await validator.validateBulkInvoices(
            invoiceIds: [passingInvoice.id, blockedInvoice.id],
            action: .bulkSendReady
        )

        XCTAssertEqual(results[passingInvoice.id]?.blockers.count, 0)
        XCTAssertTrue((results[blockedInvoice.id]?.blockers.isEmpty) == false)
    }

    @discardableResult
    private func insertBusiness(
        defaultGSTCode: String = GSTCode.p2.rawValue,
        isRegisteredProvider: Bool = false,
        ndiaOrganisationID: String? = nil
    ) throws -> BusinessEntity {
        let entity = BusinessEntity(id: UUID(), abn: "53004085616")
        entity.name = "Test Business"
        entity.defaultGstCode = defaultGSTCode
        entity.isRegisteredProvider = isRegisteredProvider
        entity.ndiaOrganisationID = ndiaOrganisationID
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertClient() throws -> ClientEntity {
        let entity = ClientEntity(
            id: UUID(),
            ndisNumber: "4300123456",
            fullName: "Test Client",
            status: .active
        )
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertSession(client: ClientEntity) throws -> SessionEntity {
        let entity = SessionEntity(id: UUID())
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
        client: ClientEntity,
        allowsTelehealth: Bool,
        allowsNonFaceToFace: Bool,
        allowsProviderTravel: Bool
    ) throws -> ServiceAgreementEntity {
        let entity = ServiceAgreementEntity(id: UUID())
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

    private func insertSupportLog(client: ClientEntity, session: SessionEntity) throws -> SupportLogEntity {
        let entity = SupportLogEntity(id: UUID())
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
        session: SessionEntity? = nil,
        claimType: NDISClaimType? = nil,
        gstCode: String? = nil
    ) throws -> InvoiceEntity {
        let invoice = InvoiceEntity(
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
            let item = InvoiceItemEntity(id: UUID(), itemDescription: "NDIS Support")
            item.invoice = invoice
            item.session = session
            item.claimType = claimType
            item.rate = 100
            item.quantity = 1
            item.gstCode = gstCode
            modelContext.insert(item)
            invoice.items.append(item)
        }

        try modelContext.save()
        return invoice
    }
}
