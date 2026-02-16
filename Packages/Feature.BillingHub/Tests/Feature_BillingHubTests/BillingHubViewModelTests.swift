import XCTest
import SwiftData
import Core
@testable import Data
@testable import Feature_BillingHub

@MainActor
final class BillingHubViewModelTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    private var sessionsRepository: SessionsRepositorySwiftData!
    private var invoicesRepository: InvoicesRepositorySwiftData!
    private var clientsRepository: ClientsRepositorySwiftData!
    private var clientServicesRepository: ClientServicesRepositorySwiftData!
    private var travelChargeRepository: TravelChargeRepositorySwiftData!
    private var businessRepository: BusinessRepositorySwiftData!
    private var ndisItemsRepository: NDISItemRepositorySwiftData!
    private var serviceAgreementRepository: ServiceAgreementRepositorySwiftData!
    private var supportLogRepository: SupportLogRepositorySwiftData!

    private var unitOfWork: SwiftDataUnitOfWork!
    private var ndisBillingService: NDISBillingService!
    private var ndisBillingIntegrationService: NDISBillingIntegrationService!
    private var complianceValidator: NDISComplianceValidator!

    private var viewModel: BillingHubViewModel!
    private var testDefaults: UserDefaults!
    private var defaultsSuiteName: String!

    override func setUp() async throws {
        try await super.setUp()

        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context

        sessionsRepository = SessionsRepositorySwiftData(modelContext: modelContext)
        invoicesRepository = InvoicesRepositorySwiftData(modelContext: modelContext)
        clientsRepository = ClientsRepositorySwiftData(modelContext: modelContext)
        clientServicesRepository = ClientServicesRepositorySwiftData(modelContext: modelContext)
        travelChargeRepository = TravelChargeRepositorySwiftData(modelContext: modelContext)
        businessRepository = BusinessRepositorySwiftData(modelContext: modelContext)
        ndisItemsRepository = NDISItemRepositorySwiftData(modelContext: modelContext)
        serviceAgreementRepository = ServiceAgreementRepositorySwiftData(modelContext: modelContext)
        supportLogRepository = SupportLogRepositorySwiftData(modelContext: modelContext)

        unitOfWork = SwiftDataUnitOfWork(modelContext: modelContext, modelContainer: modelContainer)
        ndisBillingService = NDISBillingService(unitOfWork: unitOfWork, modelContext: modelContext)
        ndisBillingIntegrationService = NDISBillingIntegrationService(
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            businessRepository: businessRepository,
            clientServicesRepository: clientServicesRepository,
            ndisItemsRepository: ndisItemsRepository,
            billingService: ndisBillingService,
            unitOfWork: unitOfWork
        )
        complianceValidator = NDISComplianceValidator(
            businessRepository: businessRepository,
            invoicesRepository: invoicesRepository,
            sessionsRepository: sessionsRepository,
            serviceAgreementRepository: serviceAgreementRepository,
            supportLogRepository: supportLogRepository
        )

        defaultsSuiteName = "Feature_BillingHubTests.\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)
        testDefaults.removePersistentDomain(forName: defaultsSuiteName)

        viewModel = makeViewModel(complianceValidator: complianceValidator)
        await waitForViewModelToSettle()
    }

    override func tearDown() async throws {
        viewModel = nil

        complianceValidator = nil
        ndisBillingIntegrationService = nil
        ndisBillingService = nil
        unitOfWork = nil

        supportLogRepository = nil
        serviceAgreementRepository = nil
        ndisItemsRepository = nil
        businessRepository = nil
        travelChargeRepository = nil
        clientServicesRepository = nil
        clientsRepository = nil
        invoicesRepository = nil
        sessionsRepository = nil

        modelContext = nil
        modelContainer = nil

        if let defaultsSuiteName {
            testDefaults?.removePersistentDomain(forName: defaultsSuiteName)
        }
        testDefaults = nil
        defaultsSuiteName = nil

        try await super.tearDown()
    }

    func testApproveDraftInvoice_BlockedByCompliance_DoesNotTransition() async throws {
        let client = try insertClient(name: "Blocked Transition Client")
        let session = try insertSession(
            title: "Missing Compliance Session",
            status: .reviewDraft,
            client: client
        )
        let invoice = try insertInvoice(
            number: "INV-BLOCK-001",
            status: .reviewDraft,
            client: client,
            session: session,
            recipientEmail: "client@example.com"
        )
        _ = try insertInvoiceItem(invoice: invoice, session: session, claimType: .direct, gstCode: "P2")

        viewModel.refresh()
        await waitForViewModelToSettle()

        await viewModel.approveDraftInvoice(id: invoice.id, dueDate: Date().addingTimeInterval(86_400 * 7))
        await waitForViewModelToSettle()

        let refreshed = try await invoicesRepository.fetch(by: invoice.id)
        XCTAssertEqual(refreshed?.status, BillingStatus.reviewDrafts.rawValue)
        XCTAssertTrue(viewModel.bulkActionFeedback?.contains("Blocked by compliance") == true)
    }

    func testApproveDraftInvoice_WarningsOnly_AllowsTransition() async throws {
        _ = try insertValidBusiness()

        let client = try insertClient(name: "Warning Transition Client")
        let session = try insertSession(
            title: "Warning Session",
            status: .reviewDraft,
            client: client
        )
        let invoice = try insertInvoice(
            number: "INV-WARN-001",
            status: .reviewDraft,
            client: client,
            session: session,
            recipientEmail: "client@example.com"
        )
        _ = try insertInvoiceItem(invoice: invoice, session: session, claimType: .direct, gstCode: nil)

        _ = try insertServiceAgreement(client: client, activeOn: session.startTime ?? Date())
        _ = try insertSupportLog(client: client, session: session)

        viewModel.refresh()
        await waitForViewModelToSettle()

        await viewModel.approveDraftInvoice(id: invoice.id, dueDate: Date().addingTimeInterval(86_400 * 7))
        await waitForViewModelToSettle()

        let refreshed = try await invoicesRepository.fetch(by: invoice.id)
        XCTAssertEqual(refreshed?.status, BillingStatus.readyToSend.rawValue)
        XCTAssertTrue(viewModel.bulkActionFeedback?.contains("Compliance warnings") == true)
    }

    func testSendAllReadyToSendInvoices_PartialSuccess_ReportsProcessedAndBlocked() async throws {
        _ = try insertValidBusiness()

        let client = try insertClient(name: "Bulk Send Client")
        let coveredAt = Date()
        _ = try insertServiceAgreement(client: client, activeOn: coveredAt)

        let passSession = try insertSession(
            title: "Bulk Send Pass Session",
            status: .readyToSend,
            client: client,
            at: coveredAt
        )
        let blockedSession = try insertSession(
            title: "Bulk Send Blocked Session",
            status: .readyToSend,
            client: client,
            at: coveredAt
        )

        let passInvoice = try insertInvoice(
            number: "INV-BULK-SEND-PASS",
            status: .readyToSend,
            client: client,
            session: passSession,
            recipientEmail: "billing@example.com"
        )
        let blockedInvoice = try insertInvoice(
            number: "INV-BULK-SEND-BLOCKED",
            status: .readyToSend,
            client: client,
            session: blockedSession,
            recipientEmail: "billing@example.com"
        )

        _ = try insertInvoiceItem(invoice: passInvoice, session: passSession, claimType: .direct, gstCode: "P2")
        _ = try insertInvoiceItem(invoice: blockedInvoice, session: blockedSession, claimType: .direct, gstCode: "P2")

        _ = try insertSupportLog(client: client, session: passSession)
        // Intentionally omit support log for blocked session.

        viewModel.refresh()
        await waitForViewModelToSettle()

        await viewModel.sendAllReadyToSendInvoices()
        await waitForViewModelToSettle()

        let refreshedPass = try await invoicesRepository.fetch(by: passInvoice.id)
        let refreshedBlocked = try await invoicesRepository.fetch(by: blockedInvoice.id)

        XCTAssertEqual(refreshedPass?.status, BillingStatus.pending.rawValue)
        XCTAssertEqual(refreshedBlocked?.status, BillingStatus.readyToSend.rawValue)
        XCTAssertTrue(viewModel.bulkActionFeedback?.contains("Processed 1, blocked 1.") == true)
    }

    func testCompleteAllPendingInvoices_PartialSuccess_ReportsProcessedAndBlocked() async throws {
        _ = try insertValidBusiness()

        let client = try insertClient(name: "Bulk Complete Client")
        let coveredAt = Date()
        _ = try insertServiceAgreement(client: client, activeOn: coveredAt)

        let passSession = try insertSession(
            title: "Bulk Complete Pass Session",
            status: .pending,
            client: client,
            at: coveredAt
        )
        let blockedSession = try insertSession(
            title: "Bulk Complete Blocked Session",
            status: .pending,
            client: client,
            at: coveredAt
        )

        let passInvoice = try insertInvoice(
            number: "INV-BULK-COMPLETE-PASS",
            status: .pending,
            client: client,
            session: passSession,
            recipientEmail: "billing@example.com"
        )
        let blockedInvoice = try insertInvoice(
            number: "INV-BULK-COMPLETE-BLOCKED",
            status: .pending,
            client: client,
            session: blockedSession,
            recipientEmail: "billing@example.com"
        )

        _ = try insertInvoiceItem(invoice: passInvoice, session: passSession, claimType: .direct, gstCode: "P2")
        _ = try insertInvoiceItem(invoice: blockedInvoice, session: blockedSession, claimType: .direct, gstCode: "P2")

        _ = try insertSupportLog(client: client, session: passSession)
        // Intentionally omit support log for blocked session.

        viewModel.refresh()
        await waitForViewModelToSettle()

        await viewModel.completeAllPendingInvoices()
        await waitForViewModelToSettle()

        let refreshedPass = try await invoicesRepository.fetch(by: passInvoice.id)
        let refreshedBlocked = try await invoicesRepository.fetch(by: blockedInvoice.id)

        XCTAssertEqual(refreshedPass?.status, BillingStatus.received.rawValue)
        XCTAssertEqual(refreshedBlocked?.status, BillingStatus.pending.rawValue)
        XCTAssertTrue(viewModel.bulkActionFeedback?.contains("Processed 1, blocked 1.") == true)
    }

    func testBillingTransitionRulesRejectsSkippedInvoiceTransitions() {
        XCTAssertFalse(BillingTransitionRules.isValidInvoiceTransition(from: .reviewDrafts, to: .pending))
        XCTAssertFalse(BillingTransitionRules.isValidInvoiceTransition(from: .reviewDrafts, to: .received))
        XCTAssertFalse(BillingTransitionRules.isValidInvoiceTransition(from: .readyToSend, to: .received))
    }

    func testMoveResultDescriptionAndSuccessFlags() {
        XCTAssertTrue(MoveResult.success.isSuccess)
        XCTAssertEqual(MoveResult.success.description, "Item moved successfully")

        XCTAssertFalse(MoveResult.notFound.isSuccess)
        XCTAssertEqual(MoveResult.notFound.description, "Item not found")

        XCTAssertFalse(MoveResult.clientMismatch.isSuccess)
        XCTAssertEqual(MoveResult.clientMismatch.description, "Sessions must belong to the same client")

        XCTAssertFalse(MoveResult.invalidTransition(from: "completed", to: "received").isSuccess)
        XCTAssertEqual(
            MoveResult.invalidTransition(from: "completed", to: "received").description,
            "Cannot move from 'completed' to 'received'"
        )
    }

    private func makeViewModel(complianceValidator: NDISComplianceValidator?) -> BillingHubViewModel {
        BillingHubViewModel(
            sessionsRepository: sessionsRepository,
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            clientServicesRepository: clientServicesRepository,
            travelChargeRepository: travelChargeRepository,
            ndisBillingIntegrationService: ndisBillingIntegrationService,
            complianceValidator: complianceValidator,
            supportLogRepository: supportLogRepository,
            complianceBlockingEnabled: true,
            userDefaults: testDefaults
        )
    }

    private func waitForViewModelToSettle() async {
        var consecutiveIdleChecks = 0
        for _ in 0..<80 {
            if viewModel.isLoading {
                consecutiveIdleChecks = 0
            } else {
                consecutiveIdleChecks += 1
                if consecutiveIdleChecks >= 4 {
                    break
                }
            }
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    @discardableResult
    private func insertClient(name: String) throws -> ClientEntity {
        let entity = ClientEntity(
            id: UUID(),
            ndisNumber: "NDIS-\(UUID().uuidString.prefix(8))",
            fullName: name,
            status: .active
        )
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    @discardableResult
    private func insertSession(
        title: String,
        status: SessionStatus,
        client: ClientEntity,
        at date: Date = Date()
    ) throws -> SessionEntity {
        let entity = SessionEntity(id: UUID())
        entity.title = title
        entity.status = status
        entity.client = client
        entity.startTime = date
        entity.endTime = date.addingTimeInterval(3600)
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    @discardableResult
    private func insertInvoice(
        number: String,
        status: InvoiceStatus,
        client: ClientEntity,
        session: SessionEntity,
        recipientEmail: String
    ) throws -> InvoiceEntity {
        let entity = InvoiceEntity(id: UUID(), invoiceNumber: number)
        entity.status = status
        entity.issueDate = Date()
        entity.date = entity.issueDate
        entity.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: entity.issueDate)
        entity.totalAmount = 120
        entity.client = client
        entity.clientName = client.fullName
        entity.clientNDISNumber = client.ndisNumber
        entity.clientEmail = recipientEmail
        entity.sessions = [session]
        session.invoice = entity
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    @discardableResult
    private func insertInvoiceItem(
        invoice: InvoiceEntity,
        session: SessionEntity,
        claimType: NDISClaimType,
        gstCode: String?
    ) throws -> InvoiceItemEntity {
        let entity = InvoiceItemEntity(id: UUID(), itemDescription: "Support")
        entity.invoice = invoice
        entity.session = session
        entity.claimType = claimType
        entity.gstCode = gstCode
        entity.quantity = 1
        entity.rate = 100
        entity.serviceDate = session.startTime ?? Date()
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    @discardableResult
    private func insertValidBusiness() throws -> BusinessEntity {
        let entity = BusinessEntity(id: UUID(), abn: "12345678901")
        entity.name = "Compliance Test Business"
        entity.defaultGstCode = "P2"
        entity.isRegisteredProvider = false
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    @discardableResult
    private func insertServiceAgreement(client: ClientEntity, activeOn date: Date) throws -> ServiceAgreementEntity {
        let entity = ServiceAgreementEntity(id: UUID())
        entity.client = client
        entity.effectiveFrom = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        entity.effectiveTo = Calendar.current.date(byAdding: .day, value: 30, to: date)
        entity.cancellationPolicyType = CancellationPolicyType.twoClearBusinessDays.rawValue
        entity.allowsProviderTravel = true
        entity.allowsTelehealth = true
        entity.allowsNonFaceToFace = true
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    @discardableResult
    private func insertSupportLog(client: ClientEntity, session: SessionEntity) throws -> SupportLogEntity {
        let entity = SupportLogEntity(id: UUID())
        entity.client = client
        entity.session = session
        entity.participantName = client.fullName
        entity.participantNdisNumber = client.ndisNumber
        entity.supportItemNumber = "01_001_0107_1_1"
        entity.serviceDescription = "In-person support"
        entity.location = "Participant home"
        entity.deliveredFrom = session.startTime ?? Date()
        entity.deliveredTo = session.endTime ?? (session.startTime ?? Date()).addingTimeInterval(3600)
        entity.quantityHours = 1
        entity.deliveredBy = "Support Worker"
        entity.attestedBy = "Support Worker"
        entity.attestedAt = Date()
        entity.signatureMethod = SignatureMethod.signature.rawValue
        entity.signedBy = "Participant"
        entity.signedAt = Date()
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }
}
