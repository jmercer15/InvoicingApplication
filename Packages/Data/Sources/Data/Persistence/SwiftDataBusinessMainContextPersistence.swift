import PersistenceModels
import DataInterfaces
import Foundation
import SwiftData

@MainActor
public final class SwiftDataBusinessMainContextPersistence: BusinessPersisting {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func saveBusiness(draft: Business, persisted: Business?) throws -> Business {
        if let persisted {
            if let address = persisted.address, address.modelContext == nil {
                modelContext.insert(address)
            }
            try modelContext.save()
            return persisted
        }

        if let address = draft.address, address.modelContext == nil {
            modelContext.insert(address)
        }
        modelContext.insert(draft)
        try modelContext.save()
        return draft
    }
}
