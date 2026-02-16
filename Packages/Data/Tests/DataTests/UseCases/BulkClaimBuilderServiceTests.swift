import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class BulkClaimBuilderServiceTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    private var invoicesRepository: InvoicesRepositorySwiftData!
    private var sessionsRepository: SessionsRepositorySwiftData!
    private var businessRepository: BusinessRepositorySwiftData!
    private var clientsRepository: ClientsRepositorySwiftData!
    private var serviceAgreementRepository: ServiceAgreementRepositorySwiftData!
    private var supportLogRepository: SupportLogRepositorySwiftData!
    private var builder: BulkClaimBuilderService!

    override func setUp() async throws {
        try await super.setUp()

        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context

        invoicesRepository = InvoicesRepositorySwiftData(modelContext: modelContext)
        sessionsRepository = SessionsRepositorySwiftData(modelContext: modelContext)
        businessRepository = BusinessRepositorySwiftData(modelContext: modelContext)
        clientsRepository = ClientsRepositorySwiftData(modelContext: modelContext)
        serviceAgreementRepository = ServiceAgreementRepositorySwiftData(modelContext: modelContext)
        supportLogRepository = SupportLogRepositorySwiftData(modelContext: modelContext)

        builder = BulkClaimBuilderService(
            invoicesRepository: invoicesRepository,
            sessionsRepository: sessionsRepository,
            businessRepository: businessRepository,
            clientsRepository: clientsRepository,
            serviceAgreementRepository: serviceAgreementRepository,
            supportLogRepository: supportLogRepository
        )
    }

    override func tearDown() async throws {
        builder = nil
        supportLogRepository = nil
        serviceAgreementRepository = nil
        clientsRepository = nil
        businessRepository = nil
        sessionsRepository = nil
        invoicesRepository = nil

        modelContext = nil
        modelContainer = nil

        try await super.tearDown()
    }

    func testBuildLinesMapsClaimTypesAndGSTFallback() async throws {
        let client = try insertClient(name: "Claim Builder Client")
        let session = try insertSession(client: client)
        let invoice = try insertInvoice(client: client, session: session)

        _ = try insertBusiness(defaultGST: "P2", ndiaOrgID: "12345")
        _ = try insertSupportLog(client: client, session: session)

        _ = try insertInvoiceItem(
            invoice: invoice,
            session: session,
            claimType: .telehealth,
            quantity: 1.5,
            unit: "hour",
            gstCode: nil,
            supportNumber: "01_001_0107_1_1"
        )
        _ = try insertInvoiceItem(
            invoice: invoice,
            session: session,
            claimType: .providerTravel,
            quantity: 1,
            unit: nil,
            gstCode: "P1",
            supportNumber: "04_590_0125_6_1"
        )

        let batchNoTravel = BulkClaimBatch(
            id: UUID(),
            fromDate: Date().addingTimeInterval(-86_400),
            toDate: Date().addingTimeInterval(86_400),
            includeTravel: false,
            includeCancellations: true,
            claimReferenceStrategy: "invoice_number"
        )

        let withoutTravel = try await builder.buildLines(for: batchNoTravel)
        XCTAssertEqual(withoutTravel.count, 1)
        XCTAssertEqual(withoutTravel[0].claimTypeCode, BPRClaimTypeCode.thlt.rawValue)
        XCTAssertEqual(withoutTravel[0].hours, "001:30")
        XCTAssertNil(withoutTravel[0].quantity)
        XCTAssertEqual(withoutTravel[0].gstCode, "P2")
        XCTAssertEqual(withoutTravel[0].registrationNumber, "12345")

        let batchWithTravel = BulkClaimBatch(
            id: UUID(),
            fromDate: Date().addingTimeInterval(-86_400),
            toDate: Date().addingTimeInterval(86_400),
            includeTravel: true,
            includeCancellations: true,
            claimReferenceStrategy: "invoice_number"
        )

        let withTravel = try await builder.buildLines(for: batchWithTravel)
        XCTAssertEqual(withTravel.count, 2)
        XCTAssertTrue(withTravel.contains(where: { $0.claimTypeCode == BPRClaimTypeCode.tran.rawValue }))
    }

    func testBuildLinesPlanManagedUsesBusinessABNForSupportProvider() async throws {
        let client = try insertClient(
            name: "Plan Managed Client",
            planManagementType: "Plan Managed",
            billingAuthority: .planManager
        )
        let session = try insertSession(client: client)
        let invoice = try insertInvoice(client: client, session: session, billingAuthority: .planManager)

        _ = try insertBusiness(defaultGST: "P2", ndiaOrgID: "12345", abn: "12 345 678 901")
        _ = try insertSupportLog(client: client, session: session)
        _ = try insertInvoiceItem(
            invoice: invoice,
            session: session,
            claimType: .direct,
            quantity: 1.0,
            unit: nil,
            gstCode: "P2",
            supportNumber: "01_001_0107_1_1"
        )

        let batch = BulkClaimBatch(
            id: UUID(),
            fromDate: Date().addingTimeInterval(-86_400),
            toDate: Date().addingTimeInterval(86_400)
        )

        let lines = try await builder.buildLines(for: batch)
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines.first?.abnOfSupportProvider, "12345678901")
    }

    func testBuildLinesNonPlanManagedLeavesSupportProviderABNBlank() async throws {
        let client = try insertClient(
            name: "Self Managed Client",
            planManagementType: "Self Managed",
            billingAuthority: .client
        )
        let session = try insertSession(client: client)
        let invoice = try insertInvoice(client: client, session: session, billingAuthority: .client)

        _ = try insertBusiness(defaultGST: "P2", ndiaOrgID: "12345", abn: "12345678901")
        _ = try insertSupportLog(client: client, session: session)
        _ = try insertInvoiceItem(
            invoice: invoice,
            session: session,
            claimType: .direct,
            quantity: 1.0,
            unit: nil,
            gstCode: "P2",
            supportNumber: "01_001_0107_1_1"
        )

        let batch = BulkClaimBatch(
            id: UUID(),
            fromDate: Date().addingTimeInterval(-86_400),
            toDate: Date().addingTimeInterval(86_400)
        )

        let lines = try await builder.buildLines(for: batch)
        XCTAssertEqual(lines.count, 1)
        XCTAssertNil(lines.first?.abnOfSupportProvider)
    }

    private func insertBusiness(defaultGST: String, ndiaOrgID: String, abn: String = "12345678901") throws -> BusinessEntity {
        let business = BusinessEntity(id: UUID(), abn: abn)
        business.name = "Claim Builder Business"
        business.defaultGstCode = defaultGST
        business.ndiaOrganisationID = ndiaOrgID
        business.isRegisteredProvider = true
        modelContext.insert(business)
        try modelContext.save()
        return business
    }

    private func insertClient(
        name: String,
        planManagementType: String? = nil,
        billingAuthority: BillingAuthority = .client
    ) throws -> ClientEntity {
        let client = ClientEntity(
            id: UUID(),
            ndisNumber: "4300000000",
            fullName: name,
            status: .active
        )
        client.planManagementType = planManagementType
        client.billingAuthority = billingAuthority
        client.sendInvoicesToPlanManager = billingAuthority == .planManager
        modelContext.insert(client)
        try modelContext.save()
        return client
    }

    private func insertSession(client: ClientEntity) throws -> SessionEntity {
        let session = SessionEntity(id: UUID())
        session.title = "Session"
        session.client = client
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        session.status = .readyToSend
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    private func insertInvoice(
        client: ClientEntity,
        session: SessionEntity,
        billingAuthority: BillingAuthority = .client
    ) throws -> InvoiceEntity {
        let invoice = InvoiceEntity(id: UUID(), invoiceNumber: "INV-CLAIM-001")
        invoice.client = client
        invoice.clientName = client.fullName
        invoice.clientNDISNumber = client.ndisNumber
        invoice.billingAuthority = billingAuthority
        invoice.status = .readyToSend
        invoice.issueDate = Date()
        invoice.date = Date()
        invoice.dueDate = Date().addingTimeInterval(86_400 * 14)
        invoice.sessions = [session]
        session.invoice = invoice
        modelContext.insert(invoice)
        try modelContext.save()
        return invoice
    }

    private func insertInvoiceItem(
        invoice: InvoiceEntity,
        session: SessionEntity,
        claimType: NDISClaimType,
        quantity: Double,
        unit: String?,
        gstCode: String?,
        supportNumber: String
    ) throws -> InvoiceItemEntity {
        let item = InvoiceItemEntity(id: UUID(), itemDescription: "Support")
        item.invoice = invoice
        item.session = session
        item.claimType = claimType
        item.quantity = quantity
        item.rate = 100
        item.serviceDate = Date()
        item.unit = unit
        item.gstCode = gstCode
        item.ndisItemNumber = supportNumber
        modelContext.insert(item)
        try modelContext.save()
        return item
    }

    private func insertSupportLog(client: ClientEntity, session: SessionEntity) throws -> SupportLogEntity {
        let log = SupportLogEntity(id: UUID())
        log.client = client
        log.session = session
        log.participantName = client.fullName
        log.participantNdisNumber = client.ndisNumber
        log.supportItemNumber = "01_001_0107_1_1"
        log.serviceDescription = "Support"
        log.location = "Home"
        log.deliveredFrom = session.startTime ?? Date()
        log.deliveredTo = session.endTime ?? Date().addingTimeInterval(3600)
        log.quantityHours = 1
        log.deliveredBy = "Worker"
        log.attestedBy = "Worker"
        log.attestedAt = Date()
        log.signatureMethod = SignatureMethod.attestation.rawValue
        log.signedBy = "Participant"
        log.signedAt = Date()
        modelContext.insert(log)
        try modelContext.save()
        return log
    }
}
