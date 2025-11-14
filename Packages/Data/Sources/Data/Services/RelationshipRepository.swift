import Foundation
import SwiftData
import Core

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
            do {
                try context.save()
            } catch {
                context.rollback()
                throw RepositoryError.saveFailed
            }
            return
        }

        // Try PayeeEntity
        let payeeDescriptor = FetchDescriptor<PayeeEntity>(predicate: #Predicate { $0.id == id })
        if let payee = try context.fetch(payeeDescriptor).first {
            context.delete(payee)
            do {
                try context.save()
            } catch {
                context.rollback()
                throw RepositoryError.saveFailed
            }
            return
        }

        // Try PlanManagerEntity
        let planManagerDescriptor = FetchDescriptor<PlanManagerEntity>(predicate: #Predicate { $0.id == id })
        if let planManager = try context.fetch(planManagerDescriptor).first {
            context.delete(planManager)
            do {
                try context.save()
            } catch {
                context.rollback()
                throw RepositoryError.saveFailed
            }
            return
        }

        // If nothing found, throw a descriptive error
        throw RepositoryError.entityNotFound
    }
}


