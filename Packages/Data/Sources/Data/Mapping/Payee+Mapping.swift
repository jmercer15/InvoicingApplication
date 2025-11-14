import Foundation
import Core

extension PayeeEntity {
    /// Update entity from domain model
    func update(from payee: Payee) {
        self.fullName = payee.fullName
        self.email = payee.email
        self.phone = payee.phone
        self.status = payee.status
        self.relationToClient = payee.relationToClient
        // Note: Address relationship is managed separately if needed
    }
}

