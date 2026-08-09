//
//  PlanManager.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class PlanManager {
    #Index<PlanManager>([\.name], [\.email], [\.phone], [\.abn])
    public var abn: String = ""
    public var id: UUID = UUID()
    public var name: String?
    public var email: String?
    public var phone: String?
    public var address: Address?
    @Relationship(deleteRule: .nullify, inverse: \Client.planManager) public var managedClients: [Client]?
    public init(id: UUID = UUID(), abn: String) {
        self.id = id
        self.abn = abn
    }
}

