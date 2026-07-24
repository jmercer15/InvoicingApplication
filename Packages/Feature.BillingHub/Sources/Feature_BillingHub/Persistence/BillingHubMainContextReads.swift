import Core
import Foundation
import SwiftData

@MainActor
struct BillingHubMainContextReads {
    let modelContext: ModelContext

    func fetchSession(id: UUID) throws -> Session? {
        var descriptor = FetchDescriptor<Session>(
            predicate: #Predicate<Session> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    func fetchInvoice(id: UUID) throws -> Invoice? {
        var descriptor = FetchDescriptor<Invoice>(
            predicate: #Predicate<Invoice> { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }
}
