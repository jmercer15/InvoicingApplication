import Foundation
import Core
import PersistenceModels
import SwiftData
import Testing
import CoreTesting
@testable import Data

/// Confirms the claim-batch mappers recognize the extended `NDISClaimType` engine strings
/// (`ProviderTravel_Labour`/`_NonLabour`/`_OtherCosts`, `ActivityTransport`) instead of only the
/// legacy unqualified `"ProviderTravel"` string.
@MainActor
@Suite(.tags(.integration))
struct NDISClaimTypeMapperTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func bulkClaimBuilderMapsProviderTravelAndActivityTransportSubtypesToTran() async throws {
        let (modelContainer, modelContext) = try makeContext()
        let client = try insertClient(into: modelContext)
        let session = try insertSession(client: client, into: modelContext)
        let invoice = try insertInvoice(client: client, session: session, into: modelContext)
        _ = try insertBusiness(into: modelContext)

        try insertInvoiceItem(invoice: invoice, session: session, claimType: .providerTravelLabour, position: 0, into: modelContext)
        try insertInvoiceItem(invoice: invoice, session: session, claimType: .providerTravelNonLabour, position: 1, into: modelContext)
        try insertInvoiceItem(invoice: invoice, session: session, claimType: .providerTravelOtherCosts, position: 2, into: modelContext)
        try insertInvoiceItem(invoice: invoice, session: session, claimType: .activityTransport, position: 3, into: modelContext)

        let batch = BulkClaimBatch(id: UUID())
        batch.fromDate = TestClock.addingTimeInterval(-86_400)
        batch.toDate = TestClock.addingTimeInterval(86_400)
        batch.includeTravel = true

        let builder = BulkClaimBuilderActor(modelContainer: modelContainer)
        let lines = try await builder.buildLines(for: batch.snapshot())

        #expect(lines.count == 4)
        for line in lines {
            #expect(line.claimTypeCode == BPRClaimTypeCode.tran.rawValue)
        }
    }

    @Test func claimBatchBuilderMapsProviderTravelAndActivityTransportSubtypesToTran() async throws {
        let (_, modelContext) = try makeContext()
        let client = try insertClient(into: modelContext)
        let session = try insertSession(client: client, into: modelContext)
        let draft = try insertDraft(session: session, client: client, into: modelContext)
        try insertClaimableLine(draft: draft, claimType: "ProviderTravel_Labour", into: modelContext)
        try insertClaimableLine(draft: draft, claimType: "ProviderTravel_NonLabour", into: modelContext)
        try insertClaimableLine(draft: draft, claimType: "ActivityTransport", into: modelContext)

        let builder = ClaimBatchBuilderService(modelContext: modelContext)
        let (_, lines) = try await builder.buildBatch(
            from: [draft.snapshot()], fromDate: TestClock.addingTimeInterval(-86_400),
            toDate: TestClock.addingTimeInterval(86_400),
            claimReferenceStrategy: "invoice_number")

        #expect(lines.count == 3)
        for line in lines {
            #expect(line.claimTypeCode == BPRClaimTypeCode.tran.rawValue)
        }
    }

    @Test func bulkClaimBuilderMapsSpecialFeeTypesToBlankPACECode() async throws {
        let (modelContainer, modelContext) = try makeContext()
        let client = try insertClient(into: modelContext)
        let session = try insertSession(client: client, into: modelContext)
        let invoice = try insertInvoice(client: client, session: session, into: modelContext)
        _ = try insertBusiness(into: modelContext)

        try insertInvoiceItem(invoice: invoice, session: session, claimType: .establishmentFee, position: 0, into: modelContext)
        try insertInvoiceItem(invoice: invoice, session: session, claimType: .nonFaceToFace, position: 1, into: modelContext)
        try insertInvoiceItem(invoice: invoice, session: session, claimType: .cancellation, position: 2, into: modelContext)

        let batch = BulkClaimBatch(id: UUID())
        batch.fromDate = TestClock.addingTimeInterval(-86_400)
        batch.toDate = TestClock.addingTimeInterval(86_400)

        let builder = BulkClaimBuilderActor(modelContainer: modelContainer)
        let lines = try await builder.buildLines(for: batch.snapshot())

        #expect(lines.count == 3)
        #expect(lines.filter { $0.claimTypeCode == nil }.count == 1)
        #expect(lines.contains { $0.claimTypeCode == BPRClaimTypeCode.nf2f.rawValue })
        #expect(lines.contains { $0.claimTypeCode == BPRClaimTypeCode.canc.rawValue })
    }

    @Test func claimBatchBuilderMapsSpecialFeeTypesToBlankPACECode() async throws {
        let (_, modelContext) = try makeContext()
        let client = try insertClient(into: modelContext)
        let session = try insertSession(client: client, into: modelContext)
        let draft = try insertDraft(session: session, client: client, into: modelContext)
        try insertClaimableLine(draft: draft, claimType: "EstablishmentFee", into: modelContext)
        try insertClaimableLine(draft: draft, claimType: "NonFaceToFace", into: modelContext)
        try insertClaimableLine(draft: draft, claimType: "Cancellation", into: modelContext)

        let builder = ClaimBatchBuilderService(modelContext: modelContext)
        let (_, lines) = try await builder.buildBatch(
            from: [draft.snapshot()], fromDate: TestClock.addingTimeInterval(-86_400),
            toDate: TestClock.addingTimeInterval(86_400),
            claimReferenceStrategy: "invoice_number")

        #expect(lines.count == 3)
        #expect(lines.filter { $0.claimTypeCode == nil }.count == 1)
        #expect(lines.contains { $0.claimTypeCode == BPRClaimTypeCode.nf2f.rawValue })
        #expect(lines.contains { $0.claimTypeCode == BPRClaimTypeCode.canc.rawValue })
    }

    private func insertBusiness(into modelContext: ModelContext) throws -> Business {
        let business = Business(id: UUID(), abn: "12345678901")
        business.name = "Claim Mapper Business"
        modelContext.insert(business)
        try modelContext.save()
        return business
    }

    private func insertClient(into modelContext: ModelContext) throws -> Client {
        let client = Client(id: UUID(), ndisNumber: "4300000002", fullName: "Mapper Client", status: .active)
        modelContext.insert(client)
        try modelContext.save()
        return client
    }

    private func insertSession(client: Client, into modelContext: ModelContext) throws -> Session {
        let session = Session(id: UUID())
        session.title = "Session"
        session.client = client
        session.startTime = TestClock.now
        session.endTime = TestClock.addingTimeInterval(3600)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    private func insertInvoice(client: Client, session: Session, into modelContext: ModelContext) throws -> Invoice {
        let invoice = Invoice(id: UUID(), invoiceNumber: "INV-MAPPER-001")
        invoice.client = client
        invoice.clientName = client.fullName
        invoice.clientNDISNumber = client.ndisNumber
        invoice.status = .readyToSend
        invoice.issueDate = TestClock.now
        invoice.date = TestClock.now
        invoice.dueDate = TestClock.addingTimeInterval(86_400 * 14)
        invoice.sessions = [session]
        session.invoice = invoice
        modelContext.insert(invoice)
        try modelContext.save()
        return invoice
    }

    @discardableResult
    private func insertInvoiceItem(
        invoice: Invoice,
        session: Session,
        claimType: NDISClaimType,
        position: Int32,
        into modelContext: ModelContext
    ) throws -> InvoiceItem {
        let item = InvoiceItem(id: UUID(), itemDescription: "Support")
        item.invoice = invoice
        item.session = session
        item.claimType = claimType
        item.position = position
        item.quantity = Decimal(1)
        item.rate = Decimal(100)
        item.serviceDate = TestClock.now
        modelContext.insert(item)
        try modelContext.save()
        return item
    }

    @discardableResult
    private func insertDraft(
        session: Session,
        client: Client,
        into modelContext: ModelContext
    ) throws -> BillableDraft {
        let draft = BillableDraft(
            id: UUID(),
            sessionId: session.id,
            clientId: client.id,
            serviceId: UUID(),
            computedAt: TestClock.now,
            billingContextSnapshot: Data(),
            draftStatus: DraftStatus.open.rawValue,
            createdAt: TestClock.now
        )
        draft.session = session
        draft.client = client
        modelContext.insert(draft)
        try modelContext.save()
        return draft
    }

    @discardableResult
    private func insertClaimableLine(draft: BillableDraft, claimType: String, into modelContext: ModelContext) throws -> ClaimableLine {
        let now = TestClock.now
        let line = ClaimableLine(
            id: UUID(),
            draftId: draft.id,
            claimType: claimType,
            supportItemNumber: "04_590_0125_6_1",
            serviceFrom: now,
            serviceTo: now.addingTimeInterval(1800),
            quantity: 5,
            unitPrice: Decimal(string: "1.10")!,
            gstCode: "P2"
        )
        line.draft = draft
        modelContext.insert(line)
        try modelContext.save()
        return line
    }
}
