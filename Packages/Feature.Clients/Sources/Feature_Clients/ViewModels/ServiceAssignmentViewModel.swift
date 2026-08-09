import PersistenceModels
import DataInterfaces
import Foundation
import Observation
import SwiftData

@Observable
@MainActor
final class ServiceAssignmentViewModel {
    let client: Client
    private let modelContext: ModelContext
    private let referenceDataFetcher: any ReferenceDataFetching

    var availableNDISItems: [NDISItem] = []
    var isLoadingItems = false

    init(
        client: Client,
        modelContext: ModelContext,
        referenceDataFetcher: any ReferenceDataFetching
    ) {
        self.client = client
        self.modelContext = modelContext
        self.referenceDataFetcher = referenceDataFetcher
    }

    func loadCatalogue() async {
        isLoadingItems = true
        defer { isLoadingItems = false }

        do {
            let ids = try await referenceDataFetcher.fetchAllNDISItemIDs()
            let idSet = Set(ids)
            let fetched = try modelContext.fetch(
                FetchDescriptor<NDISItem>(sortBy: [SortDescriptor(\.itemNumber)])
            )
            availableNDISItems = fetched.filter { idSet.contains($0.persistentModelID) }
        } catch {
            availableNDISItems = []
        }
    }
}
