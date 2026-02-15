import Foundation
import Core

/// Maps between the `Client` domain model (struct) and `ClientEntity` persistence model (SwiftData class).
public struct ClientMapper: ModelMapper {
    public typealias DomainModel = Client
    public typealias PersistenceEntity = ClientEntity
    
    public init() {}
    
    // MARK: - ModelMapper Protocol
    
    public func mapToDomain(_ entity: ClientEntity) -> Client {
        Client(
            id: entity.id,
            ndisNumber: entity.ndisNumber,
            fullName: entity.fullName,
            status: entity.status.rawValue,
            email: entity.email,
            notes: entity.notes,
            phone: entity.phone,
            creditAmount: entity.creditAmount,
            isMinor: entity.isMinor,
            hasNdisPlan: entity.hasNdisPlan,
            planManagementType: entity.planManagementType,
            billingAuthority: entity.billingAuthority?.rawValue,
            address: entity.address.map { mapAddressToDomain($0) },
            planManager: entity.planManager.map { mapPlanManagerToDomain($0) },
            payee: entity.payee.map { mapPayeeToDomain($0) },
            sendInvoicesToClient: entity.sendInvoicesToClient,
            sendInvoicesToPayee: entity.sendInvoicesToPayee,
            sendInvoicesToPlanManager: entity.sendInvoicesToPlanManager
        )
    }
    
    public func mapToEntity(_ domain: Client) -> ClientEntity {
        let entity = ClientEntity(
            id: domain.id,
            ndisNumber: domain.ndisNumber,
            fullName: domain.fullName,
            status: ClientStatus(rawValue: domain.status) ?? .active
        )
        
        // Apply all properties
        updateEntityProperties(entity, from: domain)
        
        return entity
    }
    
    public func updateEntity(_ entity: inout ClientEntity, from domain: Client) {
        updateEntityProperties(entity, from: domain)
    }
    
    // MARK: - Private Helpers
    
    private func updateEntityProperties(_ entity: ClientEntity, from domain: Client) {
        entity.ndisNumber = domain.ndisNumber
        entity.fullName = domain.fullName
        entity.status = ClientStatus(rawValue: domain.status) ?? .active
        entity.email = domain.email
        entity.notes = domain.notes
        entity.phone = domain.phone
        entity.creditAmount = domain.creditAmount
        entity.isMinor = domain.isMinor
        entity.hasNdisPlan = domain.hasNdisPlan
        entity.planManagementType = domain.planManagementType
        entity.billingAuthority = domain.billingAuthority.flatMap { BillingAuthority(rawValue: $0) }
        entity.sendInvoicesToClient = domain.sendInvoicesToClient
        entity.sendInvoicesToPayee = domain.sendInvoicesToPayee
        entity.sendInvoicesToPlanManager = domain.sendInvoicesToPlanManager
        
        // Note: Address, PlanManager, Payee relationships are handled separately
        // as they require fetching/creating related entities via repositories
    }
    
    // MARK: - Related Entity Mapping (Domain conversion only)
    
    private func mapAddressToDomain(_ entity: AddressEntity) -> Address {
        Address(
            id: entity.id,
            unitNumber: entity.unitNumber ?? "",
            streetNumber: entity.streetNumber ?? "",
            streetName: entity.streetName ?? "",
            suburb: entity.suburb ?? "",
            city: entity.city ?? "",
            state: entity.state ?? "",
            postcode: entity.postcode ?? "",
            country: entity.country ?? "",
            poBox: entity.poBox ?? "",
            latitude: entity.latitude ?? 0.0,
            longitude: entity.longitude ?? 0.0
        )
    }
    
    private func mapPlanManagerToDomain(_ entity: PlanManagerEntity) -> PlanManager {
        PlanManager(
            id: entity.id,
            name: entity.name ?? "",
            email: entity.email,
            phone: entity.phone,
            address: entity.address.map { mapAddressToDomain($0) },
            abn: entity.abn
        )
    }
    
    private func mapPayeeToDomain(_ entity: PayeeEntity) -> Payee {
        Payee(
            id: entity.id,
            fullName: entity.fullName,
            email: entity.email,
            phone: entity.phone,
            address: entity.address.map { mapAddressToDomain($0) },
            status: entity.status,
            relationToClient: entity.relationToClient
        )
    }
}
