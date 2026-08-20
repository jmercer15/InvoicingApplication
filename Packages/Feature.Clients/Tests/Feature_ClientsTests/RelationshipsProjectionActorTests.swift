import Core
import Data
import Foundation
import PersistenceModels
import SwiftData
import Testing
import CoreTesting
@testable import Feature_Clients

@MainActor
@Suite(.tags(.integration))
struct RelationshipsProjectionActorTests {
    @Test func BuildAppliesFiltersAndStableSorts() async throws {
        let (container, modelContext) = try ModelContainerFactory.makeInMemoryContext()

        let activeClient = Client(fullName: "Ann Active", status: .active)
        let inactiveClient = Client(fullName: "Ann Inactive", status: .inactive)
        let unrelatedClient = Client(fullName: "Zoe Active", status: .active)
        let matchingPayee = Payee(fullName: "Ann Payee")
        matchingPayee.status = StatusFilter.active.rawValue
        let inactivePayee = Payee(fullName: "Ann Former Payee")
        inactivePayee.status = StatusFilter.inactive.rawValue
        let matchingManager = PlanManager(abn: "111")
        matchingManager.name = "Ann Manager"
        let unrelatedManager = PlanManager(abn: "222")
        unrelatedManager.name = "Zoe Manager"

        modelContext.insert(activeClient)
        modelContext.insert(inactiveClient)
        modelContext.insert(unrelatedClient)
        modelContext.insert(matchingPayee)
        modelContext.insert(inactivePayee)
        modelContext.insert(matchingManager)
        modelContext.insert(unrelatedManager)
        try modelContext.save()

        let actor = RelationshipsProjectionActor(modelContainer: container)
        let projection = try await actor.build(
            searchText: "ann",
            selectedFilter: .all,
            selectedStatus: .active
        )

        #expect(sectionTitles(in: projection) == ["Clients", "Payees", "Plan Managers"])
        #expect(childTitles(in: projection, section: "Clients") == ["Ann Active"])
        #expect(childTitles(in: projection, section: "Payees") == ["Ann Payee"])
        #expect(childTitles(in: projection, section: "Plan Managers") == ["Ann Manager"])
    }

    private func sectionTitles(in projection: RelationshipsProjection) -> [String] {
        projection.tree.map(\.title)
    }

    private func childTitles(in projection: RelationshipsProjection, section: String) -> [String] {
        projection.tree.first { $0.title == section }?.children?.map(\.title) ?? []
    }
}
