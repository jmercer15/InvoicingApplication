import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class ServiceAgreementRepositoryTests: XCTestCase {
    private var modelContext: ModelContext!
    private var repository: ServiceAgreementRepositorySwiftData!

    override func setUp() async throws {
        try await super.setUp()
        let container = try ModelContainer(
            for: complianceSchema(),
            configurations: [ModelConfiguration(schema: complianceSchema(), isStoredInMemoryOnly: true)]
        )
        modelContext = ModelContext(container)
        repository = ServiceAgreementRepositorySwiftData(modelContext: modelContext)
    }

    override func tearDown() async throws {
        repository = nil
        modelContext = nil
        try await super.tearDown()
    }

    func testHasOverlapHandlesOpenEndedAndBoundedRanges() async throws {
        let client = try insertClient()

        _ = try await repository.create(
            ServiceAgreement(
                id: UUID(),
                clientId: client.id,
                effectiveFrom: makeDate(2026, 1, 1),
                effectiveTo: nil
            )
        )

        let overlapsOpenEnded = try await repository.hasOverlap(
            clientId: client.id,
            effectiveFrom: makeDate(2026, 1, 15),
            effectiveTo: makeDate(2026, 1, 31),
            excluding: nil
        )
        XCTAssertTrue(overlapsOpenEnded)

        let noOverlapBeforeRange = try await repository.hasOverlap(
            clientId: client.id,
            effectiveFrom: makeDate(2025, 1, 1),
            effectiveTo: makeDate(2025, 1, 31),
            excluding: nil
        )
        XCTAssertFalse(noOverlapBeforeRange)
    }

    func testHasOverlapIgnoresExcludedAgreement() async throws {
        let client = try insertClient()
        let existing = try await repository.create(
            ServiceAgreement(
                id: UUID(),
                clientId: client.id,
                effectiveFrom: makeDate(2026, 1, 1),
                effectiveTo: makeDate(2026, 12, 31)
            )
        )

        let overlapsWithoutExclusion = try await repository.hasOverlap(
            clientId: client.id,
            effectiveFrom: makeDate(2026, 3, 1),
            effectiveTo: makeDate(2026, 3, 31),
            excluding: nil
        )
        XCTAssertTrue(overlapsWithoutExclusion)

        let overlapsWithExclusion = try await repository.hasOverlap(
            clientId: client.id,
            effectiveFrom: makeDate(2026, 3, 1),
            effectiveTo: makeDate(2026, 3, 31),
            excluding: existing.id
        )
        XCTAssertFalse(overlapsWithExclusion)
    }

    func testFetchActiveReturnsAgreementForDate() async throws {
        let client = try insertClient()
        let janAgreement = try await repository.create(
            ServiceAgreement(
                id: UUID(),
                clientId: client.id,
                effectiveFrom: makeDate(2026, 1, 1),
                effectiveTo: makeDate(2026, 1, 31)
            )
        )
        let febAgreement = try await repository.create(
            ServiceAgreement(
                id: UUID(),
                clientId: client.id,
                effectiveFrom: makeDate(2026, 2, 1),
                effectiveTo: nil
            )
        )

        let janActive = try await repository.fetchActive(clientId: client.id, on: makeDate(2026, 1, 20))
        let febActive = try await repository.fetchActive(clientId: client.id, on: makeDate(2026, 2, 20))

        XCTAssertEqual(janActive?.id, janAgreement.id)
        XCTAssertEqual(febActive?.id, febAgreement.id)
    }

    private func insertClient() throws -> ClientEntity {
        let client = ClientEntity(
            id: UUID(),
            ndisNumber: "4300\(Int.random(in: 100000...999999))",
            fullName: "Service Agreement Test Client",
            status: .active
        )
        modelContext.insert(client)
        try modelContext.save()
        return client
    }

    private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 12
        return Calendar(identifier: .gregorian).date(from: components) ?? Date()
    }
}

func complianceSchema() -> Schema {
    Schema([
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
}
