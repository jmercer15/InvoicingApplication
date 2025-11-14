import Foundation
import Core

extension Client {
    /// Convert from ClientEntity to domain model
    init(from entity: ClientEntity) {
        self.init(
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
            address: entity.address.map { Address(from: $0) },
            planManager: entity.planManager.map { PlanManager(from: $0) },
            payee: entity.payee.map { Payee(from: $0) },
            sendInvoicesToClient: entity.sendInvoicesToClient,
            sendInvoicesToPayee: entity.sendInvoicesToPayee,
            sendInvoicesToPlanManager: entity.sendInvoicesToPlanManager
        )
    }
}

extension Address {
    /// Convert from AddressEntity to domain model
    init(from entity: AddressEntity) {
        self.init(
            id: entity.id,
            unitNumber: entity.unitNumber,
            streetNumber: entity.streetNumber,
            streetName: entity.streetName,
            suburb: entity.suburb,
            city: entity.city,
            state: entity.state,
            postcode: entity.postcode,
            country: entity.country,
            poBox: entity.poBox,
            latitude: entity.latitude,
            longitude: entity.longitude
        )
    }
}

extension AddressEntity {
    /// Update entity from domain model
    func update(from address: Address) {
        self.id = address.id
        self.unitNumber = address.unitNumber
        self.streetNumber = address.streetNumber
        self.streetName = address.streetName
        self.suburb = address.suburb
        self.city = address.city
        self.state = address.state
        self.postcode = address.postcode
        self.country = address.country
        self.poBox = address.poBox
        self.latitude = address.latitude
        self.longitude = address.longitude
        // Update fullAddressText to match the formatted address
        self.fullAddressText = address.fullFormattedAddress
    }
}

extension PlanManager {
    /// Convert from PlanManagerEntity to domain model
    init(from entity: PlanManagerEntity) {
        self.init(
            id: entity.id,
            name: entity.name ?? "",
            email: entity.email,
            phone: entity.phone,
            address: entity.address.map { Address(from: $0) },
            abn: entity.abn
        )
    }
}

extension Payee {
    /// Convert from PayeeEntity to domain model
    init(from entity: PayeeEntity) {
        self.init(
            id: entity.id,
            fullName: entity.fullName,
            email: entity.email,
            phone: entity.phone,
            address: entity.address.map { Address(from: $0) },
            status: entity.status,
            relationToClient: entity.relationToClient
        )
    }
}

extension ClientEntity {
    /// Update entity from domain model
    func update(from client: Client) {
        self.ndisNumber = client.ndisNumber
        self.fullName = client.fullName
        self.status = ClientStatus(rawValue: client.status) ?? .active
        self.email = client.email
        self.notes = client.notes
        self.phone = client.phone
        self.creditAmount = client.creditAmount
        self.isMinor = client.isMinor
        self.hasNdisPlan = client.hasNdisPlan
        self.planManagementType = client.planManagementType
        self.billingAuthority = client.billingAuthority.flatMap { BillingAuthority(rawValue: $0) }
        self.sendInvoicesToClient = client.sendInvoicesToClient
        self.sendInvoicesToPayee = client.sendInvoicesToPayee
        self.sendInvoicesToPlanManager = client.sendInvoicesToPlanManager
        
        // Handle address update if provided
        if let address = client.address {
            if let existingAddress = self.address {
                // Update existing address using domain model
                existingAddress.update(from: address)
            } else {
                // Create new address
                let addressEntity = AddressEntity()
                addressEntity.update(from: address)
                self.address = addressEntity
            }
        } else {
            // Remove address if client.address is nil
            self.address = nil
        }
    }
}

// MARK: - Public Helper Functions for Cross-Module Conversion

/// Public helper to convert ClientEntity to Client domain model
/// Use this from Feature packages to avoid Codable init(from:) conflicts
public func clientFromEntity(_ entity: ClientEntity) -> Client {
    return Client(from: entity)
}

/// Public helper to convert PayeeEntity to Payee domain model
/// Use this from Feature packages to avoid Codable init(from:) conflicts
public func payeeFromEntity(_ entity: PayeeEntity) -> Payee {
    return Payee(from: entity)
}

/// Public helper to convert PlanManagerEntity to PlanManager domain model
/// Use this from Feature packages to avoid Codable init(from:) conflicts
public func planManagerFromEntity(_ entity: PlanManagerEntity) -> PlanManager {
    return PlanManager(from: entity)
}
