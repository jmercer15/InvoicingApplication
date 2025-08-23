//
//  ClientServiceEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class ClientServiceEntity {
    public var id: UUID
    var serviceName: String = ""
    var unit: String = ""
    var rate: Double = 0.0
    var clientServiceID: Int32? = 0
    var endDate: Date?
    var isActive: Bool = true
    var ndisCode: String?
    var startDate: Date?
    var status: String?
    var ndisItem: NDISItemEntity?
    @Relationship(deleteRule: .nullify) var client: ClientEntity?
    @Relationship(deleteRule: .nullify) var invoiceItems: [InvoiceItemEntity]?
    var sessions: [SessionEntity]?
    var travelCharges: [TravelChargeEntity]?
    public init(id: UUID, serviceName: String, unit: String, rate: Double) {
        self.id = id
        self.serviceName = serviceName
        self.unit = unit
        self.rate = rate
    }
}

extension ClientServiceEntity: DropdownRepresentable {
    var displayName: String { serviceName }
}
