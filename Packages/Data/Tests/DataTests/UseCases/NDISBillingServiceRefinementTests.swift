import XCTest
import CoreLocation
import SwiftData
import Core
@testable import Data

/// Verification tests for Phase 9 NDIS Billing Refinements
@MainActor
final class NDISBillingServiceRefinementTests: XCTestCase {
    
    private var modelContext: ModelContext!
    private var repository: NDISItemRepository!
    private var configService: NDISBillingConfigService!
    private var billingService: NDISBillingService!
    private var integrationService: NDISBillingIntegrationService!
    private var invoicesRepo: InvoicesRepository!
    private var clientsRepo: ClientsRepository!
    private var businessRepo: BusinessRepository!
    private var clientServicesRepo: ClientServicesRepository!
    private var unitOfWork: UnitOfWorkService!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup in-memory SwiftData
        let models: [any PersistentModel.Type] = [NDISItemEntity.self, RegionalPriceEntity.self]
        let (_, context) = try ModelContainerFactory.makeInMemoryContext(models: models)
        modelContext = context
        
        repository = NDISItemRepositorySwiftData(modelContext: modelContext)
        configService = NDISBillingConfigService()
        billingService = NDISBillingService(modelContext: modelContext, repository: repository, configService: configService)
        
        // Mock Repositories (Simplified for brevity in this specific refinement test)
        // In a real scenario, these would be the SwiftData implementations
        // unitOfWork = UnitOfWorkSwiftData(modelContext: modelContext)
        // integrationService = NDISBillingIntegrationService(...)
    }
    
    // MARK: - Phase 10: Robustness & Context Detection
    
    func testShadowShiftKeywordDetection() throws {
        // Given: Session notes with "introductory shift"
        let session = Session(
            id: UUID(),
            title: "Intro Session",
            notes: "Initial meeting - strictly an introductory shift for the new worker.",
            status: "completed"
        )
        
        // When: Creating context info (private but accessible via integration service logic)
        // We'll test the logic directly if possible or via integration service helper
        let integrationService = NDISBillingIntegrationService(
            invoicesRepository: InvoicesRepositoryMock(),
            clientsRepository: ClientsRepositoryMock(),
            businessRepository: BusinessRepositoryMock(),
            clientServicesRepository: ClientServicesRepositoryMock(),
            ndisItemsRepository: repository,
            billingService: billingService,
            unitOfWork: UnitOfWorkServiceMock()
        )
        
        let context = integrationService.createContextInfo(from: session)
        
        // Then
        XCTAssertTrue(context.isShadowShift, "Shadow shift should be detected from 'introductory shift'")
    }
    
    func testHighIntensityKeywordDetection() throws {
        // Given: Session notes with "subcutaneous injection"
        let session = Session(
            id: UUID(),
            title: "Clinical Support",
            notes: "Provided support including a subcutaneous injection as per plan.",
            status: "completed"
        )
        
        let integrationService = NDISBillingIntegrationService(
            invoicesRepository: InvoicesRepositoryMock(),
            clientsRepository: ClientsRepositoryMock(),
            businessRepository: BusinessRepositoryMock(),
            clientServicesRepository: ClientServicesRepositoryMock(),
            ndisItemsRepository: repository,
            billingService: billingService,
            unitOfWork: UnitOfWorkServiceMock()
        )
        
        let context = integrationService.createContextInfo(from: session)
        
        // Then
        XCTAssertTrue(context.isHighIntensity, "High intensity should be detected from 'subcutaneous injection'")
    }
    
    // MARK: - MMM Zone Refinement Tests
    
    func testCoordinateBasedMMMLookup() throws {
        // Given: Sydney coordinates (MMM1)
        let sydneyLocation = NDISLocation(
            postcode: "2000",
            latitude: -33.8688,
            longitude: 151.2093
        )
        
        // When
        let mmmRating = configService.getMmmRating(for: sydneyLocation)
        
        // Then
        XCTAssertEqual(mmmRating, 1, "Sydney coordinates should resolve to MMM1")
    }
    
    func testRemoteCoordinateBasedMMMLookup() throws {
        // Given: Alice Springs coordinates (MMM6 - Remote)
        let aliceSpringsLocation = NDISLocation(
            postcode: "0870",
            latitude: -23.6980,
            longitude: 133.8807
        )
        
        // When
        let mmmRating = configService.getMmmRating(for: aliceSpringsLocation)
        
        // Then
        XCTAssertEqual(mmmRating, 6, "Alice Springs coordinates should resolve to MMM6")
    }
    
    // MARK: - Cancellation Logic Tests
    
    func testShortNoticeCancellationWithClearBusinessDays() throws {
        // Given: Service on Monday morning
        let calendar = Calendar.current
        let nextMonday = calendar.nextDate(after: Date(), matching: DateComponents(weekday: 2), matchingPolicy: .nextTime)!
        let serviceTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nextMonday)!
        
        // Notice given on Friday afternoon (not enough clear business days if requirement is 2 clear days)
        // Clear business days between Friday afternoon and Monday morning: Saturday (no), Sunday (no) -> 0 clear business days.
        let noticeTime = calendar.date(byAdding: .day, value: -3, to: serviceTime)!
        
        // When
        let isSufficientNotice = configService.checkNoticePeriod(
            noticeTime: noticeTime,
            serviceTime: serviceTime,
            amount: 2,
            unit: "clear_business_days"
        )
        
        // Then
        XCTAssertFalse(isSufficientNotice, "Friday to Monday should not provide 2 clear business days")
    }
    
    func testSufficientNoticeCancellationWithClearBusinessDays() throws {
        // Given: Service on Thursday
        let calendar = Calendar.current
        let nextThursday = calendar.nextDate(after: Date(), matching: DateComponents(weekday: 5), matchingPolicy: .nextTime)!
        let serviceTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: nextThursday)!
        
        // Notice given on Monday (Clear business days: Tuesday, Wednesday -> 2 clear days)
        let noticeTime = calendar.date(byAdding: .day, value: -3, to: serviceTime)!
        
        // When
        let isSufficientNotice = configService.checkNoticePeriod(
            noticeTime: noticeTime,
            serviceTime: serviceTime,
            amount: 2,
            unit: "clear_business_days"
        )
        
        // Then
        XCTAssertTrue(isSufficientNotice, "Monday to Thursday provides 2 clear business days (Tue, Wed)")
    }
    
    // MARK: - Centralized Rate Tests
    
    func testCentreCapitalCostRateCentralization() throws {
        // Given: MMM1 location
        let location = NDISLocation(postcode: "2000")
        
        // When
        let rate = configService.getCentreCapitalRate(for: location)
        
        // Then
        XCTAssertEqual(rate, 0.50, "MMM1 Centre Capital rate should be $0.50")
    }
    
    func testEstablishmentFeeRateCentralization() throws {
        // Given: MMM7 location
        let location = NDISLocation(postcode: "6799") // Remote WA
        
        // When
        let fee = configService.getEstablishmentFeeRate(for: location)
        
        // Then
        XCTAssertEqual(fee, 400.0, "MMM7 Establishment Fee should be $400.00")
    }
}

// MARK: - Mocks for Testing

final class InvoicesRepositoryMock: InvoicesRepository {
    func fetchAll() async throws -> [Invoice] { [] }
    func fetch(byClientId clientId: UUID) async throws -> [Invoice] { [] }
    func fetch(by status: String) async throws -> [Invoice] { [] }
    func fetch(by billingStatus: BillingStatus) async throws -> [Invoice] { [] }
    func fetch(by id: UUID) async throws -> Invoice? { nil }
    func fetch(by invoiceNumber: String) async throws -> Invoice? { nil }
    func create(_ invoice: Invoice) async throws -> Invoice { invoice }
    func update(_ invoice: Invoice) async throws -> Invoice { invoice }
    func delete(id: UUID) async throws {}
    func updateStatus(id: UUID, status: String) async throws {}
    func updateBillingStatus(id: UUID, status: BillingStatus) async throws {}
    func createFromSessions(_ sessionIds: [UUID], clientId: UUID) async throws -> Invoice { fatalError() }
    func addItem(_ item: InvoiceItem) async throws -> InvoiceItem { item }
    func updateItem(_ item: InvoiceItem) async throws -> InvoiceItem { item }
    func removeItem(id: UUID) async throws {}
    func fetchItems(by invoiceId: UUID) async throws -> [InvoiceItem] { [] }
    func search(query: String) async throws -> [Invoice] { [] }
    func fetch(limit: Int, offset: Int) async throws -> [Invoice] { [] }
    func count() async throws -> Int { 0 }
    func count(by status: String) async throws -> Int { 0 }
    func generateInvoiceNumber() async throws -> String { "INV-001" }
}

final class ClientsRepositoryMock: ClientsRepository {
    func fetch(by id: UUID) async throws -> Client? { nil }
    func fetch(by ndisNumber: String) async throws -> Client? { nil }
    func fetchActive() async throws -> [Client] { [] }
    func fetchAll() async throws -> [Client] { [] }
    func create(_ client: Client) async throws -> Client { client }
    func update(_ client: Client) async throws -> Client { client }
    func delete(id: UUID) async throws {}
    func fetch(limit: Int, offset: Int) async throws -> [Client] { [] }
    func count() async throws -> Int { 0 }
    func countActive() async throws -> Int { 0 }
    func fetch(byPayeeId payeeId: UUID) async throws -> [Client] { [] }
    func fetch(byPlanManagerId planManagerId: UUID) async throws -> [Client] { [] }
    func archive(id: UUID) async throws {}
    func reactivate(id: UUID) async throws {}
    func updateStatus(id: UUID, status: String) async throws {}
    func search(query: String) async throws -> [Client] { [] }
    func fetch(query: String, limit: Int, offset: Int) async throws -> [Client] { [] }
}

final class BusinessRepositoryMock: BusinessRepository {
    func fetch(by id: UUID) async throws -> Business? { nil }
    func fetchFirst() async throws -> Business? { nil }
    func update(_ business: Business) async throws -> Business { business }
    func fetchAll() async throws -> [Business] { [] }
}

final class ClientServicesRepositoryMock: ClientServicesRepository {
    func fetch(by id: UUID) async throws -> ClientService? { nil }
    func fetch(for clientId: UUID) async throws -> [ClientService] { [] }
    func fetchByClient(clientId: UUID) async throws -> [ClientService] { [] }
    func create(_ service: ClientService) async throws -> ClientService { service }
    func update(_ service: ClientService) async throws -> ClientService { service }
    func delete(id: UUID) async throws {}
    func fetchAll() async throws -> [ClientService] { [] }
}

final class UnitOfWorkServiceMock: UnitOfWorkService {
    var clients: any ClientsRepository { ClientsRepositoryMock() }
    var sessions: any SessionsRepository { fatalError("Not implemented") }
    var invoices: any InvoicesRepository { InvoicesRepositoryMock() }
    var clientServices: any ClientServicesRepository { ClientServicesRepositoryMock() }
    var ndisItems: any NDISItemRepository { fatalError("Not implemented") }
    var payees: any PayeeRepository { fatalError("Not implemented") }
    var planManagers: any PlanManagerRepository { fatalError("Not implemented") }
    var business: any BusinessRepository { BusinessRepositoryMock() }
    var addresses: any AddressRepository { fatalError("Not implemented") }
    var travelCharges: any TravelChargeRepository { fatalError("Not implemented") }
    var travelChargeReviewItems: any TravelChargeReviewRepository { fatalError("Not implemented") }
    var serviceAgreements: any ServiceAgreementRepository { ServiceAgreementRepositoryMock() }
    var supportLogs: any SupportLogRepository { SupportLogRepositoryMock() }
    var bulkClaims: any BulkClaimRepository { BulkClaimRepositoryMock() }
    var soleTraderCredentials: any SoleTraderComplianceCredentialRepository { fatalError("Not implemented") }
    func saveChanges() async throws {}
    func rollback() async {}
    func createChildContext() -> any UnitOfWorkService { self }
    func wipeAllData() async throws -> (totalDeleted: Int, deletedByEntity: [String: Int]) { (0, [:]) }
}

final class ServiceAgreementRepositoryMock: ServiceAgreementRepository {
    func fetch(by id: UUID) async throws -> ServiceAgreement? { nil }
    func fetchByClient(_ clientId: UUID, includeArchived: Bool) async throws -> [ServiceAgreement] { [] }
    func fetchActive(clientId: UUID, on date: Date) async throws -> ServiceAgreement? { nil }
    func create(_ agreement: ServiceAgreement) async throws -> ServiceAgreement { agreement }
    func update(_ agreement: ServiceAgreement) async throws -> ServiceAgreement { agreement }
    func archive(id: UUID) async throws {}
    func delete(id: UUID) async throws {}
    func hasOverlap(clientId: UUID, effectiveFrom: Date, effectiveTo: Date?, excluding agreementId: UUID?) async throws -> Bool { false }
}

final class SupportLogRepositoryMock: SupportLogRepository {
    func fetch(by id: UUID) async throws -> SupportLog? { nil }
    func fetchBySession(_ sessionId: UUID) async throws -> [SupportLog] { [] }
    func fetchByClient(_ clientId: UUID, from: Date?, to: Date?) async throws -> [SupportLog] { [] }
    func create(_ log: SupportLog) async throws -> SupportLog { log }
    func update(_ log: SupportLog) async throws -> SupportLog { log }
    func delete(id: UUID) async throws {}
}

final class BulkClaimRepositoryMock: BulkClaimRepository {
    func createBatch(_ batch: BulkClaimBatch) async throws -> BulkClaimBatch { batch }
    func fetchBatches() async throws -> [BulkClaimBatch] { [] }
    func fetchBatch(by id: UUID) async throws -> BulkClaimBatch? { nil }
    func fetchLines(batchId: UUID) async throws -> [BulkClaimLine] { [] }
    func replaceLines(batchId: UUID, lines: [BulkClaimLine]) async throws {}
    func updateBatchLineReconciliation(
        batchId: UUID,
        submissionStatus: BulkClaimSubmissionStatus,
        submissionRef: String?,
        reconciliationNotes: String?,
        reconciledAt: Date?
    ) async throws -> Int { 0 }
    func updateBatchStatus(id: UUID, status: BulkClaimBatchStatus, errorCount: Int) async throws {}
    func markExported(id: UUID, fileName: String, checksumSHA256: String, rowCount: Int) async throws {}
    func deleteBatch(id: UUID) async throws {}
}
