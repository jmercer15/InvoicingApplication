import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite(.tags(.integration))
struct EntityPredicateBuildersTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func billableDraftPlanTypePredicateFiltersDenormalizedColumn() throws {
        let (_, context) = try makeContext()
        let planManaged = Client(id: UUID(), fullName: "Plan Managed")
        planManaged.planManagementType = "Plan Managed"
        let ndiaManaged = Client(id: UUID(), fullName: "NDIA Managed")
        ndiaManaged.planManagementType = "NDIA Managed"
        context.insert(planManaged)
        context.insert(ndiaManaged)

        let planDraft = BillableDraft(
            id: UUID(),
            sessionId: UUID(),
            clientId: planManaged.id,
            clientPlanManagementType: "Plan Managed",
            serviceId: UUID(),
            computedAt: TestClock.now,
            billingContextSnapshot: Data(),
            draftStatus: DraftStatus.open.rawValue,
            createdAt: TestClock.now
        )
        let ndiaDraft = BillableDraft(
            id: UUID(),
            sessionId: UUID(),
            clientId: ndiaManaged.id,
            clientPlanManagementType: "NDIA Managed",
            serviceId: UUID(),
            computedAt: TestClock.now,
            billingContextSnapshot: Data(),
            draftStatus: DraftStatus.open.rawValue,
            createdAt: TestClock.now
        )
        context.insert(planDraft)
        context.insert(ndiaDraft)
        try context.save()

        let descriptor = FetchDescriptor<BillableDraft>(
            predicate: EntityPredicateBuilders.billableDrafts(planType: "Plan Managed")
        )
        let matches = try context.fetch(descriptor)
        #expect(matches.count == 1)
        #expect(matches.first?.id == planDraft.id)
    }

    @Test func backfillBillableDraftPlanTypeCopiesClientPlanManagementType() throws {
        let (_, context) = try makeContext()
        let client = Client(id: UUID(), fullName: "Backfill Client")
        client.planManagementType = "Self Managed"
        context.insert(client)

        let draft = BillableDraft(
            id: UUID(), sessionId: UUID(),
            clientId: client.id,
            serviceId: UUID(),
            computedAt: TestClock.now,
            billingContextSnapshot: Data(),
            draftStatus: DraftStatus.open.rawValue,
            createdAt: TestClock.now)
        context.insert(draft)
        try context.save()

        try BackfillBillableDraftPlanType_v1.execute(modelContext: context)
        #expect(draft.clientPlanManagementType == "Self Managed")
    }
}
