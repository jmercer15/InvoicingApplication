import Foundation
import SwiftData
import PersistenceModels
import DataInterfaces

/// Read-only invoice aggregates on the SwiftData model-actor executor (e.g. numbering without scanning on the UI context).
public actor InvoiceDigestActor: InvoiceDigesting, ModelActor {
    nonisolated public let modelContainer: ModelContainer
    nonisolated public let modelExecutor: any ModelExecutor

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: context)
    }

    public func allInvoiceNumbers() async throws -> [String] {
        let descriptor = FetchDescriptor<Invoice>()
        return try modelContext.fetch(descriptor).map(\.invoiceNumber)
    }
}
