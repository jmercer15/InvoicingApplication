import XCTest
import SwiftData
import Core
@testable import Data
@testable import Feature_Invoices
import Feature_InvoiceTemplateEditor

@MainActor
final class InvoiceEditorViewModelComplianceTests: XCTestCase {
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!

    private var invoicesRepository: InvoicesRepositorySwiftData!
    private var clientServicesRepository: ClientServicesRepositorySwiftData!
    private var clientsRepository: ClientsRepositorySwiftData!
    private var payeesRepository: PayeeRepositorySwiftData!
    private var planManagersRepository: PlanManagerRepositorySwiftData!
    private var businessRepository: BusinessRepositorySwiftData!
    private var sessionsRepository: SessionsRepositorySwiftData!
    private var serviceAgreementRepository: ServiceAgreementRepositorySwiftData!
    private var supportLogRepository: SupportLogRepositorySwiftData!

    private var complianceValidator: NDISComplianceValidator!
    private var sharingService: InvoiceSharingService!

    override func setUp() async throws {
        try await super.setUp()

        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContainer = container
        modelContext = context

        invoicesRepository = InvoicesRepositorySwiftData(modelContext: modelContext)
        clientServicesRepository = ClientServicesRepositorySwiftData(modelContext: modelContext)
        clientsRepository = ClientsRepositorySwiftData(modelContext: modelContext)
        payeesRepository = PayeeRepositorySwiftData(modelContext: modelContext)
        planManagersRepository = PlanManagerRepositorySwiftData(modelContext: modelContext)
        businessRepository = BusinessRepositorySwiftData(modelContext: modelContext)
        sessionsRepository = SessionsRepositorySwiftData(modelContext: modelContext)
        serviceAgreementRepository = ServiceAgreementRepositorySwiftData(modelContext: modelContext)
        supportLogRepository = SupportLogRepositorySwiftData(modelContext: modelContext)

        complianceValidator = NDISComplianceValidator(
            businessRepository: businessRepository,
            invoicesRepository: invoicesRepository,
            sessionsRepository: sessionsRepository,
            serviceAgreementRepository: serviceAgreementRepository,
            supportLogRepository: supportLogRepository
        )

        let templateDataService = TemplateDataService(
            invoicesRepository: invoicesRepository,
            clientsRepository: clientsRepository,
            businessRepository: businessRepository,
            payeeRepository: payeesRepository
        )
        sharingService = InvoiceSharingService(
            templateManager: TemplateManager(),
            templateDataService: templateDataService
        )
    }

    override func tearDown() async throws {
        sharingService = nil
        complianceValidator = nil

        supportLogRepository = nil
        serviceAgreementRepository = nil
        sessionsRepository = nil
        businessRepository = nil
        planManagersRepository = nil
        payeesRepository = nil
        clientsRepository = nil
        clientServicesRepository = nil
        invoicesRepository = nil

        modelContext = nil
        modelContainer = nil

        try await super.tearDown()
    }

    func testMarkAsSent_BlockerPreventsTransition() async throws {
        let client = try insertClient(name: "Sent Blocked Client")
        let session = try insertSession(title: "Sent Blocked Session", status: .reviewDraft, client: client)
        let invoiceEntity = try insertInvoice(number: "INV-SENT-BLOCKED", status: .reviewDraft, client: client, session: session)
        _ = try insertInvoiceItem(invoice: invoiceEntity, session: session, claimType: .direct, gstCode: "P2")

        guard let invoice = try await invoicesRepository.fetch(by: invoiceEntity.id) else {
            XCTFail("Expected invoice to exist")
            return
        }

        let viewModel = makeInvoiceEditorViewModel(invoice: invoice)
        await waitForEditorToSettle(viewModel)

        viewModel.markAsSent()
        try? await Task.sleep(nanoseconds: 300_000_000)

        let refreshed = try await invoicesRepository.fetch(by: invoiceEntity.id)
        XCTAssertEqual(refreshed?.status, InvoiceStatus.reviewDraft.rawValue)
        XCTAssertTrue(viewModel.complianceStatusIsBlocker)
        XCTAssertTrue(viewModel.complianceStatusMessage?.contains("Blocked by compliance") == true)
    }

    func testMarkAsSent_WarningsOnlyAllowsTransition() async throws {
        _ = try insertValidBusiness()

        let client = try insertClient(name: "Sent Warning Client")
        let session = try insertSession(title: "Sent Warning Session", status: .reviewDraft, client: client)
        _ = try insertServiceAgreement(client: client, activeOn: session.startTime ?? Date())
        _ = try insertSupportLog(client: client, session: session)

        let invoiceEntity = try insertInvoice(number: "INV-SENT-WARN", status: .reviewDraft, client: client, session: session)
        _ = try insertInvoiceItem(invoice: invoiceEntity, session: session, claimType: .direct, gstCode: nil)

        guard let invoice = try await invoicesRepository.fetch(by: invoiceEntity.id) else {
            XCTFail("Expected invoice to exist")
            return
        }

        let viewModel = makeInvoiceEditorViewModel(invoice: invoice)
        await waitForEditorToSettle(viewModel)

        viewModel.markAsSent()
        _ = try await waitForInvoiceStatus(invoiceId: invoiceEntity.id, expected: InvoiceStatus.pending.rawValue)

        let refreshed = try await invoicesRepository.fetch(by: invoiceEntity.id)
        XCTAssertEqual(refreshed?.status, InvoiceStatus.pending.rawValue)
        XCTAssertFalse(viewModel.complianceStatusIsBlocker)
        XCTAssertTrue(viewModel.complianceStatusMessage?.contains("Compliance warnings") == true)
    }

    func testMarkAsPaid_BlockerPreventsTransition() async throws {
        let client = try insertClient(name: "Paid Blocked Client")
        let session = try insertSession(title: "Paid Blocked Session", status: .pending, client: client)
        let invoiceEntity = try insertInvoice(number: "INV-PAID-BLOCKED", status: .pending, client: client, session: session)
        _ = try insertInvoiceItem(invoice: invoiceEntity, session: session, claimType: .direct, gstCode: "P2")

        guard let invoice = try await invoicesRepository.fetch(by: invoiceEntity.id) else {
            XCTFail("Expected invoice to exist")
            return
        }

        let viewModel = makeInvoiceEditorViewModel(invoice: invoice)
        await waitForEditorToSettle(viewModel)

        viewModel.markAsPaid()
        try? await Task.sleep(nanoseconds: 300_000_000)

        let refreshed = try await invoicesRepository.fetch(by: invoiceEntity.id)
        XCTAssertEqual(refreshed?.status, InvoiceStatus.pending.rawValue)
        XCTAssertTrue(viewModel.complianceStatusIsBlocker)
        XCTAssertTrue(viewModel.complianceStatusMessage?.contains("Blocked by compliance") == true)
    }

    private func makeInvoiceEditorViewModel(invoice: Invoice) -> InvoiceEditorViewModel {
        InvoiceEditorViewModel(
            invoicesRepository: invoicesRepository,
            clientServicesRepository: clientServicesRepository,
            clientsRepository: clientsRepository,
            payeesRepository: payeesRepository,
            planManagersRepository: planManagersRepository,
            sharingService: sharingService,
            invoice: invoice,
            isNew: false,
            complianceValidator: complianceValidator,
            complianceBlockingEnabled: true
        )
    }

    private func waitForEditorToSettle(_ viewModel: InvoiceEditorViewModel) async {
        var idleChecks = 0
        for _ in 0..<120 {
            let itemsLoaded = !viewModel.invoiceItems.isEmpty
            if !viewModel.isLoading && itemsLoaded {
                idleChecks += 1
                if idleChecks >= 3 { break }
            } else {
                idleChecks = 0
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }

    @discardableResult
    private func waitForInvoiceStatus(invoiceId: UUID, expected: String) async throws -> Invoice {
        for _ in 0..<120 {
            if let invoice = try await invoicesRepository.fetch(by: invoiceId), invoice.status == expected {
                return invoice
            }
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        if let invoice = try await invoicesRepository.fetch(by: invoiceId) {
            XCTFail("Invoice status did not reach \(expected). Final status: \(invoice.status)")
            return invoice
        }

        XCTFail("Invoice not found while waiting for status \(expected)")
        throw NSError(domain: "InvoiceEditorViewModelComplianceTests", code: 1)
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
    private func insertSession(title: String, status: SessionStatus, client: ClientEntity, at date: Date = Date()) throws -> SessionEntity {
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
    private func insertInvoice(number: String, status: InvoiceStatus, client: ClientEntity, session: SessionEntity) throws -> InvoiceEntity {
        let entity = InvoiceEntity(id: UUID(), invoiceNumber: number)
        entity.status = status
        entity.issueDate = Date()
        entity.date = entity.issueDate
        entity.dueDate = Calendar.current.date(byAdding: .day, value: 14, to: entity.issueDate)
        entity.totalAmount = 100
        entity.client = client
        entity.clientName = client.fullName
        entity.clientNDISNumber = client.ndisNumber
        entity.clientEmail = "client@example.com"
        entity.sessions = [session]
        session.invoice = entity
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    @discardableResult
    private func insertInvoiceItem(invoice: InvoiceEntity, session: SessionEntity, claimType: NDISClaimType, gstCode: String?) throws -> InvoiceItemEntity {
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
        entity.name = "Invoice Compliance Business"
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
        entity.serviceDescription = "Support"
        entity.location = "Home"
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
