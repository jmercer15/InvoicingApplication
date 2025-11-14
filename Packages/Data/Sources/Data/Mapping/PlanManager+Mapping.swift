import Foundation
import Core

extension PlanManagerEntity {
    /// Update entity from domain model
    func update(from planManager: PlanManager) {
        self.name = planManager.name
        self.email = planManager.email
        self.phone = planManager.phone
        self.abn = planManager.abn
        // Note: Address relationship is managed separately if needed
    }
}

