import Core
import PersistenceModels
import DataInterfaces
import Foundation
import SwiftData

@MainActor
public final class SwiftDataTravelChargeReviewMainContextPersistence: TravelChargeReviewFetching {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAllReviewItems() throws -> [TravelChargeReviewRow] {
        try modelContext.fetch(FetchDescriptor<TravelChargeReviewItem>()).map { item in
            TravelChargeReviewRow(snapshot: item.snapshot(), persistentModelID: item.persistentModelID)
        }
    }
}
