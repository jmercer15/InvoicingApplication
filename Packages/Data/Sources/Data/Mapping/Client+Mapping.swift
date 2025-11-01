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
            street: "\(entity.streetNumber) \(entity.streetName)".trimmingCharacters(in: .whitespaces),
            city: entity.city,
            state: entity.state,
            postcode: entity.postcode,
            country: entity.country
        )
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
            status: entity.status
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
    }
}
