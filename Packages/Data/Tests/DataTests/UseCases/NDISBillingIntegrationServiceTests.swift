import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

/// Covers the Workstream 1 fixes to `NDISBillingIntegrationService.generateNDISInvoice`:
/// - the created invoice is linked to the seller `Business` and snapshotted before save
/// - `InvoiceCreationDefaults.taxRate` is applied to both the invoice and its line items
/// - draft-derived hour lines parse `hoursHHHMM` instead of silently coercing to a zero quantity
/// - `resolveBillingContext` prefers a persisted `TravelCharge` over the MapKit fallback
@MainActor
@Suite(.tags(.integration))
struct NDISBillingIntegrationServiceTests {
    private func makeFixture() throws -> (ModelContainer, ModelContext, NDISBillingIntegrationService) {
        let (container, context) = try ModelContainerFactory.makeInMemoryContext()
        let service = NDISBillingIntegrationService(
            modelContainer: container,
            geocodingService: SwiftDataGeocodingService(),
            mmmZoneLookup: MMMZoneLookup()
        )
        return (container, context, service)
    }

    // MARK: - Business linking, snapshotting, and tax rate

    @Test func generateNDISInvoiceLinksBusinessSnapshotsDataAndAppliesTaxRate() async throws {
        let (_, modelContext, service) = try makeFixture()
        let business = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft, quantity: 2, hoursHHHMM: nil, unitPrice: 50)

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)

        #expect(report.successfulSessionsCount == 1)
        let invoiceSnapshot = try #require(report.invoice)
        let expectedTaxRate = InvoiceCreationDefaults.load(from: .standard).taxRate

        #expect(invoiceSnapshot.businessId == business.id)
        #expect(invoiceSnapshot.businessName == business.name)
        #expect(invoiceSnapshot.businessABN == business.abn)
        #expect(invoiceSnapshot.taxRate == Decimal(expectedTaxRate))

        let invoiceId = invoiceSnapshot.id
        let persistedInvoice = try #require(
            modelContext.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == invoiceId })).first
        )
        #expect(persistedInvoice.business?.id == business.id)
        #expect(persistedInvoice.bankBSB == business.bankBSB)
        #expect(persistedInvoice.bankAccountNumber == business.bankAccountNumber)

        let item = try #require(persistedInvoice.itemsArray.first)
        // Draft helper defaults to P2 (GST-free) → tax 0. Use P1 for taxable default-rate coverage.
        #expect(item.gstCode == GSTCode.p2.rawValue)
        #expect(item.taxRate == 0)
    }

    @Test func generateNDISInvoiceAppliesDefaultTaxRateForTaxableGSTCode() async throws {
        let (_, modelContext, service) = try makeFixture()
        _ = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft,
            quantity: 2,
            hoursHHHMM: nil,
            unitPrice: 50,
            gstCode: GSTCode.p1.rawValue)

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)
        let invoiceId = try #require(report.invoice?.id)
        let persistedInvoice = try #require(
            modelContext.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == invoiceId })).first
        )
        let item = try #require(persistedInvoice.itemsArray.first)
        let expectedTaxRate = InvoiceCreationDefaults.load(from: .standard).taxRate
        #expect(item.gstCode == GSTCode.p1.rawValue)
        #expect(item.taxRate == Decimal(expectedTaxRate))
    }

    // MARK: - Hour-draft quantity parsing

    @Test func draftLineParsesHoursHHHMMWhenQuantityDecimalIsNil() async throws {
        let (_, modelContext, service) = try makeFixture()
        _ = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft, quantity: nil, hoursHHHMM: "002:30", unitPrice: 40)

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)

        #expect(report.successfulSessionsCount == 1)
        let invoiceSnapshot = try #require(report.invoice)
        let invoiceId = invoiceSnapshot.id
        let persistedInvoice = try #require(
            modelContext.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == invoiceId })).first
        )
        let item = try #require(persistedInvoice.itemsArray.first)

        // "002:30" is 2 hours 30 minutes -> 2.5 decimal hours. Before the fix this silently
        // coerced to 0 because only `quantityDecimal` was consulted.
        #expect(item.quantity == Decimal(string: "2.5"))
        #expect(item.rate == Decimal(40))
    }

    @Test func decimalHoursParsesHHHMMFormat() {
        #expect(NDISBillingIntegrationService.decimalHours(fromHHHMM: "002:30") == 2.5)
        #expect(NDISBillingIntegrationService.decimalHours(fromHHHMM: "000:15") == 0.25)
        #expect(NDISBillingIntegrationService.decimalHours(fromHHHMM: "not-a-time") == nil)
        #expect(NDISBillingIntegrationService.decimalHours(fromHHHMM: "001:90") == nil)
        #expect(NDISBillingIntegrationService.decimalHours(fromHHHMM: "002:60") == nil)
    }

    @Test func draftLineWithZeroQuantityFailsSession() async throws {
        let (_, modelContext, service) = try makeFixture()
        _ = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft, quantity: 0, hoursHHHMM: nil, unitPrice: 40)

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)

        #expect(report.successfulSessionsCount == 0)
        #expect(report.failedSessions.count == 1)
        #expect(report.invoice == nil)
        #expect(report.failedSessions[0].reason.contains("zero or invalid"))
    }

    @Test func draftLineWithInvalidMinutesFailsSession() async throws {
        let (_, modelContext, service) = try makeFixture()
        _ = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft, quantity: nil, hoursHHHMM: "001:90", unitPrice: 40)

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)

        #expect(report.successfulSessionsCount == 0)
        #expect(report.failedSessions.count == 1)
        #expect(report.invoice == nil)
    }

    @Test func generateNDISInvoiceUsesHumanDescriptionUnitAndGSTFreeTax() async throws {
        let (_, modelContext, service) = try makeFixture()
        _ = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        let serviceEntity = ClientService(id: UUID(), serviceName: "Daily Living", unit: "hour", rate: 50)
        serviceEntity.ndisCode = "01_001_0107_1_1"
        serviceEntity.gstCode = GSTCode.p2.rawValue
        serviceEntity.client = client
        session.clientService = serviceEntity
        modelContext.insert(serviceEntity)
        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft, quantity: 2, hoursHHHMM: nil, unitPrice: 50)

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)

        let invoiceId = try #require(report.invoice?.id)
        let persistedInvoice = try #require(
            modelContext.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == invoiceId })).first
        )
        let item = try #require(persistedInvoice.itemsArray.first)
        #expect(item.itemDescription == "Daily Living (01_001_0107_1_1)")
        #expect(item.unit == "hour")
        #expect(item.gstCode == GSTCode.p2.rawValue)
        #expect(item.taxRate == 0)
        #expect(item.quantity == Decimal(2))
        #expect(item.rate == Decimal(50))
    }

    @Test func persistedTravelTotalsPreserveDirectionAndApplyMMMCap() throws {
        let (_, modelContext, service) = try makeFixture()
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)

        let before = TravelCharge(id: UUID(), distanceKM: 5, durationMinutes: 45, parkingCost: 0, tollCost: 0)
        before.travelDirection = .before
        before.mmmZoneName = "MMM 1-3"
        before.linkedSession = session
        modelContext.insert(before)

        let after = TravelCharge(id: UUID(), distanceKM: 3, durationMinutes: 20, parkingCost: 1, tollCost: 2)
        after.travelDirection = .after
        after.mmmZoneName = "MMM 1-3"
        after.linkedSession = session
        modelContext.insert(after)
        try modelContext.save()

        let totals = try #require(
            NDISBillingIntegrationService.resolvePersistedTravelTotals(forSessionId: session.id, in: modelContext)
        )
        // MMM 1-3 caps at 30 minutes.
        #expect(totals.timeToMinutes == 30)
        #expect(totals.timeFromMinutes == 20)
        #expect(totals.distanceKM == 8)
        #expect(totals.tolls == 2)
        #expect(totals.parking == 1)
    }

    @Test func lineDescriptionFormatsNameAndCode() {
        #expect(
            NDISBillingIntegrationService.lineDescription(serviceName: "Support", code: "01_001") == "Support (01_001)"
        )
        #expect(NDISBillingIntegrationService.lineDescription(serviceName: nil, code: "01_001") == "01_001")
    }

    // MARK: - TravelCharge preference over MapKit fallback

    @Test func resolveBillingContextPrefersPersistedTravelChargeOverMapKitFallback() async throws {
        let (_, modelContext, service) = try makeFixture()
        let client = try insertClient(into: modelContext)
        // No clientService/coordinates set, so the MapKit automation flow fails fast at
        // validation without making any network call.
        let session = try insertSession(into: modelContext, client: client)

        let travelCharge = TravelCharge(
            id: UUID(), distanceKM: 12.5,
            durationMinutes: 22,
            parkingCost: 4,
            tollCost: 2.5)
        travelCharge.linkedSession = session
        modelContext.insert(travelCharge)
        try modelContext.save()

        let context = await service.resolveBillingContext(forSessionId: session.id)

        #expect(context.travelDistance == 12.5)
        #expect(context.travelTime == 22)
        #expect(context.travelTolls == 2.5)
        #expect(context.travelParking == 4)
        #expect(context.isProviderTravel)
    }

    @Test func resolveBillingContextLeavesDefaultsWhenNoTravelChargeIsPersisted() async throws {
        let (_, modelContext, service) = try makeFixture()
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)

        let context = await service.resolveBillingContext(forSessionId: session.id)

        #expect(context.travelDistance == 0)
        #expect(context.travelTime == 0)
        #expect(context.travelTolls == 0)
        #expect(context.travelParking == 0)
    }

    @Test func draftPathMergesTravelWhenChargesExistWithoutTravelLines() async throws {
        let (_, modelContext, service) = try makeFixture()
        _ = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        session.title = "Draft Travel Merge"
        let item = try insertProviderTravelItem(into: modelContext, itemNumber: "15_100_0117_1_3", nationalPrice: 100)
        let serviceEntity = ClientService(id: UUID(), serviceName: "Support", unit: "hour", rate: 90)
        serviceEntity.ndisCode = item.itemNumber
        serviceEntity.ndisItem = item
        serviceEntity.client = client
        session.clientService = serviceEntity
        modelContext.insert(serviceEntity)

        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft, quantity: 1, hoursHHHMM: nil, unitPrice: 90)

        let charge = TravelCharge(
            id: UUID(), chargeAmount: 18.5,
            distanceKM: 0,
            durationMinutes: 25,
            chargeType: .labour,
            vehicleType: .standardCar,
            parkingCost: 0,
            tollCost: 0)
        charge.linkedSession = session
        modelContext.insert(charge)
        try modelContext.save()

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)

        #expect(report.successfulSessionsCount == 1, "failures: \(report.failedSessions.map(\.reason))")
        let invoiceId = try #require(report.invoice?.id)
        let persistedInvoice = try #require(
            modelContext.fetch(FetchDescriptor<Invoice>(predicate: #Predicate { $0.id == invoiceId })).first
        )
        let labour = try #require(
            persistedInvoice.itemsArray.first(where: { $0.claimType == .providerTravelLabour }),
            "Expected ProviderTravel_Labour merge, got \(persistedInvoice.itemsArray.map { String(describing: $0.claimType) })"
        )
        #expect(labour.rate == Decimal(string: "18.5")!)
        #expect(persistedInvoice.itemsArray.count >= 2)
    }

    @Test func draftWithBothTravelMethodsFailsInsteadOfDoubleBilling() async throws {
        let (_, modelContext, service) = try makeFixture()
        _ = try insertBusiness(into: modelContext)
        let client = try insertClient(into: modelContext)
        let session = try insertSession(into: modelContext, client: client)
        let draft = try insertDraft(into: modelContext, session: session, client: client)
        try insertClaimableLine(into: modelContext, draft: draft,
            claimType: NDISClaimType.activityTransport.rawValue,
            quantity: 1,
            hoursHHHMM: nil,
            unitPrice: 12)
        try insertClaimableLine(into: modelContext,
            draft: draft,
            claimType: NDISClaimType.providerTravelLabour.rawValue,
            quantity: 1,
            hoursHHHMM: nil,
            unitPrice: 18
        )

        let report = try await service.generateNDISInvoice(for: [session.id], clientId: client.id)

        #expect(report.invoice == nil)
        #expect(report.successfulSessionsCount == 0)
        #expect(report.failedSessions.count == 1)
        #expect(
            report.failedSessions[0].reason == "Draft includes both Activity Transport and Provider Travel. Keep only one travel method."
        )
    }

    @Test func labourChargesStayProviderDespiteActivityEligibleService() async throws {
        let (_, modelContext, service) = try makeFixture()
        let client = try insertClient(into: modelContext)
        let item = try insertProviderTravelItem(into: modelContext,
            itemNumber: "02_590_0107_1_1",
            nationalPrice: 100,
            name: "Community Access Transport",
            description: "activity based transport",
            category: "Transport"
        )
        let serviceEntity = ClientService(id: UUID(), serviceName: item.name, unit: "H", rate: 90)
        serviceEntity.ndisCode = item.itemNumber
        serviceEntity.ndisItem = item
        serviceEntity.client = client
        let session = try insertSession(into: modelContext, client: client)
        session.clientService = serviceEntity
        modelContext.insert(serviceEntity)

        let charge = TravelCharge(
            id: UUID(),
            chargeAmount: 12,
            distanceKM: 0,
            durationMinutes: 15,
            chargeType: .labour,
            parkingCost: 0,
            tollCost: 0
        )
        charge.linkedSession = session
        modelContext.insert(charge)
        try modelContext.save()

        let context = await service.resolveBillingContext(forSessionId: session.id)
        #expect(context.isProviderTravel)
        #expect(context.isActivityTransport == false)
    }

    // MARK: - Test Helpers

    private func insertBusiness(into modelContext: ModelContext) throws -> Business {
        let business = Business(id: UUID(), abn: "12345678901")
        business.name = "Acme NDIS Services"
        business.email = "billing@acme.test"
        business.bankName = "Test Bank"
        business.bankAccountName = "Acme NDIS"
        business.bankBSB = "123-456"
        business.bankAccountNumber = "987654321"
        modelContext.insert(business)
        try modelContext.save()
        return business
    }

    private func insertClient(into modelContext: ModelContext, name: String = "Jamie Client") throws -> Client {
        let client = Client(id: UUID(), ndisNumber: "4300000001", fullName: name, status: .active)
        modelContext.insert(client)
        try modelContext.save()
        return client
    }

    @discardableResult
    private func insertProviderTravelItem(
        into modelContext: ModelContext,
        itemNumber: String,
        nationalPrice: Double,
        name: String = "Test Support",
        description: String = "Test",
        category: String = "Test"
    ) throws -> NDISItem {
        let entity = NDISItem(id: UUID())
        entity.itemNumber = itemNumber
        entity.name = name
        entity.itemDescription = description
        entity.category = category
        entity.unit = "H"
        entity.isCurrent = true
        entity.status = "Active"
        entity.quoteRequired = false
        entity.providerTravel = true

        let price = RegionalPrice(id: UUID())
        price.regionIdentifier = "National"
        price.amount = Decimal(nationalPrice)
        price.ndisItem = entity
        modelContext.insert(price)
        modelContext.insert(entity)
        try modelContext.save()
        return entity
    }

    private func insertSession(into modelContext: ModelContext, client: Client) throws -> Session {
        let session = Session(id: UUID())
        session.title = "Session"
        session.client = client
        session.startTime = TestClock.now
        session.endTime = TestClock.addingTimeInterval(3600)
        modelContext.insert(session)
        try modelContext.save()
        return session
    }

    @discardableResult
    private func insertDraft(
        into modelContext: ModelContext,
        session: Session,
        client: Client
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
    private func insertClaimableLine(
        into modelContext: ModelContext,
        draft: BillableDraft,
        claimType: String = "Direct",
        supportItemNumber: String = "01_001_0107_1_1",
        quantity: Decimal?,
        hoursHHHMM: String?,
        unitPrice: Decimal,
        gstCode: String = "P2"
    ) throws -> ClaimableLine {
        let now = TestClock.now
        let line = ClaimableLine(
            id: UUID(),
            draftId: draft.id,
            claimType: claimType,
            supportItemNumber: supportItemNumber,
            serviceFrom: now,
            serviceTo: now.addingTimeInterval(3600),
            quantity: quantity,
            hoursHHHMM: hoursHHHMM,
            unitPrice: unitPrice,
            gstCode: gstCode
        )
        line.draft = draft
        modelContext.insert(line)
        try modelContext.save()
        return line
    }
}
