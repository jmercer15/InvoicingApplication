import DataInterfaces
import Foundation
import SwiftData
import PersistenceModels

@MainActor
public final class SwiftDataDatabaseHealthChecker: DatabaseHealthChecking {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func verifyConnection() throws {
        _ = try modelContext.fetch(FetchDescriptor<Business>())
    }
}
