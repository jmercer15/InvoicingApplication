import PersistenceModels
import Foundation
import SwiftData

struct ClientDetailProjection {
    let clientId: UUID
    let clientServices: [ClientService]
    let relatedInvoices: [Invoice]
    let serviceAgreements: [ServiceAgreement]

    var refreshTaskID: ClientDetailProjectionRefreshID {
        ClientDetailProjectionRefreshID(
            clientId: clientId,
            clientServices: clientServices,
            relatedInvoices: relatedInvoices,
            serviceAgreements: serviceAgreements
        )
    }
}

struct ClientDetailProjectionRefreshID: Equatable {
    let clientId: UUID
    let clientServicesRevision: Int
    let relatedInvoicesRevision: Int
    let serviceAgreementsRevision: Int

    init(
        clientId: UUID,
        clientServices: [ClientService],
        relatedInvoices: [Invoice],
        serviceAgreements: [ServiceAgreement]
    ) {
        self.clientId = clientId
        self.clientServicesRevision = Self.hashEntities(clientServices)
        self.relatedInvoicesRevision = Self.hashEntities(relatedInvoices)
        self.serviceAgreementsRevision = Self.hashEntities(serviceAgreements)
    }

    private static func hashEntities<T: PersistentModel>(_ entities: [T]) -> Int {
        var hasher = Hasher()
        for entity in entities {
            hasher.combine(entity.id)
        }
        return hasher.finalize()
    }
}
