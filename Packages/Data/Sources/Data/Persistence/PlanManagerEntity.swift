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
    #Index<PlanManagerEntity>([\.name], [\.email], [\.phone], [\.abn])
    @Attribute(.unique) public var abn: String
    public var id: UUID
    public var name: String?
    public var email: String?
    public var phone: String?
    public var address: AddressEntity?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.planManager) public var managedClients: [ClientEntity]?
    public init(id: UUID, abn: String) {
        self.id = id
        self.abn = abn
    }
}


