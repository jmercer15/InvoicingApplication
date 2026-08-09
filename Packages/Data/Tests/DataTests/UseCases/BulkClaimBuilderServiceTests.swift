import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite struct BulkClaimBuilderActorTests {
    private typealias PersistenceBillingAuthority = BillingAuthority
    private typealias PersistenceNDISClaimType = NDISClaimType
    private typealias PersistenceInvoiceStatus = InvoiceStatus
    private typealias PersistenceSessionStatus = SessionStatus

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext
    private let builder: BulkClaimBuilderActor

    init() throws {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        self.modelContainer = container
        self.modelContext = context
        self.builder = BulkClaimBuilderActor(modelContainer: container)
    }

    @Test func BuildLinesMapsClaimTypesAndGSTFallback() async throws {
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

        let batchNoTravel = makeBatch(includeTravel: false)

        let withoutTravel = try await builder.buildLines(for: batchNoTravel.snapshot())
        #expect(withoutTravel.count == 1)
        #expect(withoutTravel[0].claimTypeCode == BPRClaimTypeCode.thlt.rawValue)
        #expect(withoutTravel[0].hours == "001:30")
        #expect(withoutTravel[0].quantity == nil)
        #expect(withoutTravel[0].gstCode == "P2")
        #expect(withoutTravel[0].registrationNumber == "12345")

        let batchWithTravel = makeBatch(includeTravel: true)

        let withTravel = try await builder.buildLines(for: batchWithTravel.snapshot())
        #expect(withTravel.count == 2)
        #expect(withTravel.contains(where: { $0.claimTypeCode == BPRClaimTypeCode.tran.rawValue }))
    }

    @Test func BuildLinesPlanManagedUsesBusinessABNForSupportProvider() async throws {
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

        let batch = makeBatch()

        let lines = try await builder.buildLines(for: batch.snapshot())
        #expect(lines.count == 1)
        #expect(lines.first?.abnOfSupportProvider == "12345678901")
    }

    @Test func BuildLinesNonPlanManagedLeavesSupportProviderABNBlank() async throws {
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

        let batch = makeBatch()

        let lines = try await builder.buildLines(for: batch.snapshot())
        #expect(lines.count == 1)
        #expect(lines.first?.abnOfSupportProvider == nil)
    }

    @Test func BuildLinesByBatchIDLoadsPersistedBatch() async throws {
        let client = try insertClient(name: "Batch ID Client")
        let session = try insertSession(client: client)
        let invoice = try insertInvoice(client: client, session: session)

        _ = try insertBusiness(defaultGST: "P2", ndiaOrgID: "12345")
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

        let batch = makeBatch()
        modelContext.insert(batch)
        try modelContext.save()

        let lines = try await builder.buildLines(batchID: batch.id)
        #expect(lines.count == 1)
        #expect(lines.first?.batchId == batch.id)
    }

    @Test func BuildLinesByBatchModelIDLoadsPersistedBatch() async throws {
        let client = try insertClient(name: "Batch Model ID Client")
        let session = try insertSession(client: client)
        let invoice = try insertInvoice(client: client, session: session)

        _ = try insertBusiness(defaultGST: "P2", ndiaOrgID: "12345")
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

        let batch = makeBatch()
        modelContext.insert(batch)
        try modelContext.save()

        let lines = try await builder.buildLines(batchModelID: batch.persistentModelID)
        #expect(lines.count == 1)
        #expect(lines.first?.batchId == batch.id)
    }

    @Test func BuildLinesByDeletedBatchModelIDThrowsTypedNotFoundError() async throws {
        let batch = makeBatch()
        modelContext.insert(batch)
        try modelContext.save()
        let deletedModelID = batch.persistentModelID
        modelContext.delete(batch)
        try modelContext.save()

        do {
            _ = try await builder.buildLines(batchModelID: deletedModelID)
            Issue.record("Expected deleted batch model identifier to throw.")
        } catch let error as BulkClaimBuilderActorError {
            #expect(error == .batchModelNotFound)
        }
    }

    @Test func BuildLinesByBatchIDThrowsWhenBatchMissing() async throws {
        let missingBatchID = UUID()
        do {
            _ = try await builder.buildLines(batchID: missingBatchID)
            Issue.record("Expected missing batch to throw.")
        } catch let error as BulkClaimBuilderActorError {
            #expect(error == .batchNotFound(missingBatchID))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    private func makeBatch(
        includeTravel: Bool = true,
        includeCancellations: Bool = true,
        claimReferenceStrategy: String = "invoice_number"
    ) -> BulkClaimBatch {
        let batch = BulkClaimBatch(id: UUID())
        batch.fromDate = Date().addingTimeInterval(-86_400)
        batch.toDate = Date().addingTimeInterval(86_400)
        batch.includeTravel = includeTravel
        batch.includeCancellations = includeCancellations
        batch.claimReferenceStrategy = claimReferenceStrategy
        return batch
    }

    private func insertBusiness(defaultGST: String, ndiaOrgID: String, abn: String = "12345678901") throws -> Business {
        let business = Business(id: UUID(), abn: abn)
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
        billingAuthority: PersistenceBillingAuthority = .client
    ) throws -> Client {
        let client = Client(
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

    private func insertSession(client: Client) throws -> Session {
        let session = Session(id: UUID())
        session.title = "Session"
        session.client = client
        session.startTime = Date()
        session.endTime = Date().addingTimeInterval(3600)
        session.status = PersistenceSessionStatus.readyToSend
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    private func insertInvoice(
        client: Client,
        session: Session,
        billingAuthority: PersistenceBillingAuthority = .client
    ) throws -> Invoice {
        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-CLAIM-001")
        invoice.client = client
        invoice.clientName = client.fullName
        invoice.clientNDISNumber = client.ndisNumber
        invoice.billingAuthority = billingAuthority
        invoice.status = PersistenceInvoiceStatus.readyToSend
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
        invoice: Invoice,
        session: Session,
        claimType: PersistenceNDISClaimType,
        quantity: Double,
        unit: String?,
        gstCode: String?,
        supportNumber: String
    ) throws -> InvoiceItem {
        let item = InvoiceItem(id: UUID(), itemDescription: "Support")
        item.invoice = invoice
        item.session = session
        item.claimType = claimType
        item.quantity = Decimal(quantity)
        item.rate = Decimal(100)
        item.serviceDate = Date()
        item.unit = unit
        item.gstCode = gstCode
        item.ndisItemNumber = supportNumber
        modelContext.insert(item)
        try modelContext.save()
        return item
    }

    private func insertSupportLog(client: Client, session: Session) throws -> SupportLog {
        let log = SupportLog(id: UUID())
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
