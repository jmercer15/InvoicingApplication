//
//  PlanManagerEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class PlanManagerEntity {
    @Attribute(.unique) var abn: String
    public var id: UUID
    var businessName: String?
    var email: String?
    var phone: String?
    var address: AddressEntity?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.planManager) var managedClients: [ClientEntity]?
    public init(id: UUID, abn: String) {
        self.id = id
        self.abn = abn
    }
}

extension PlanManagerEntity: DropdownRepresentable {
    var displayName: String { businessName ?? "" }
}
