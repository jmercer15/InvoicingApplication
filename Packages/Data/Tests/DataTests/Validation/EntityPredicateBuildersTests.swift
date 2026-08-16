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

    @Test func billableDraftCombinedPredicateAppliesStatusDateAndClient() throws {
        let (_, context) = try makeContext()
        let matchingClientID = UUID()
        let otherClientID = UUID()
        let lowerBound = TestClock.addingTimeInterval(-60)
        let upperBound = TestClock.addingTimeInterval(60)

        func makeDraft(
            clientID: UUID,
            status: DraftStatus,
            computedAt: Date
        ) -> BillableDraft {
            BillableDraft(
                id: UUID(),
                sessionId: UUID(),
                clientId: clientID,
                serviceId: UUID(),
                computedAt: computedAt,
                billingContextSnapshot: Data(),
                draftStatus: status.rawValue,
                createdAt: TestClock.now
            )
        }

        let lowerBoundary = makeDraft(
            clientID: matchingClientID,
            status: .open,
            computedAt: lowerBound
        )
        let upperBoundary = makeDraft(
            clientID: matchingClientID,
            status: .open,
            computedAt: upperBound
        )
        let wrongClient = makeDraft(
            clientID: otherClientID,
            status: .open,
            computedAt: TestClock.now
        )
        let wrongStatus = makeDraft(
            clientID: matchingClientID,
            status: .locked,
            computedAt: TestClock.now
        )
        let outsideRange = makeDraft(
            clientID: matchingClientID,
            status: .open,
            computedAt: TestClock.addingTimeInterval(61)
        )

        [lowerBoundary, upperBoundary, wrongClient, wrongStatus, outsideRange]
            .forEach(context.insert)
        try context.save()

        let descriptor = FetchDescriptor<BillableDraft>(
            predicate: EntityPredicateBuilders.billableDrafts(
                statusRaw: DraftStatus.open.rawValue,
                rangeLower: lowerBound,
                rangeUpper: upperBound,
                clientId: matchingClientID
            ),
            sortBy: [SortDescriptor(\.computedAt)]
        )
        let matches = try context.fetch(descriptor)

        #expect(matches.map(\.id) == [lowerBoundary.id, upperBoundary.id])
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
