import Foundation
import SwiftData

public final class RelationshipRepository {
    private let context: ModelContext

    public init(context: ModelContext) {
        self.context = context
    }

    public func deleteRelationship(withId id: UUID) throws {
        // Try ClientEntity
        let clientDescriptor = FetchDescriptor<ClientEntity>(predicate: #Predicate { $0.id == id })
        if let client = try context.fetch(clientDescriptor).first {
            context.delete(client)
            return
        }

        // Try PayeeEntity
        let payeeDescriptor = FetchDescriptor<PayeeEntity>(predicate: #Predicate { $0.id == id })
        if let payee = try context.fetch(payeeDescriptor).first {
            context.delete(payee)
            return
        }

        // Try PlanManagerEntity
        let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>(predicate: #Predicate { $0.id == id })
        if let planManager = try context.fetch(planManagerDescriptor).first {
            context.delete(planManager)
            return
        }

        // If nothing found, throw a descriptive error
        throw NSError(domain: "RelationshipRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Could not find relationship with id \(id)"])
    }
}


