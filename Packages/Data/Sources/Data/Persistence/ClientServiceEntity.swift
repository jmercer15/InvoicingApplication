//
//  ClientServiceEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class ClientServiceEntity: @unchecked Sendable {
    public var id: UUID
    public var serviceName: String = ""
    public var unit: String = ""
    public var rate: Double = 0.0
    public var clientServiceID: Int32? = 0
    public var endDate: Date?
    public var isActive: Bool = true
    public var ndisCode: String?
    public var startDate: Date?
    public var status: String?
    @Relationship(deleteRule: .nullify) public var ndisItem: NDISItemEntity?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.clientServices) public var client: ClientEntity?
    @Relationship(deleteRule: .nullify, inverse: \InvoiceItemEntity.clientService) public var invoiceItems: [InvoiceItemEntity] = []
    @Relationship(deleteRule: .cascade) public var sessions: [SessionEntity] = []
    @Relationship(deleteRule: .cascade, inverse: \TravelChargeEntity.service) public var travelCharges: [TravelChargeEntity] = []
    public init(id: UUID, serviceName: String, unit: String, rate: Double) {
        self.id = id
        self.serviceName = serviceName
        self.unit = unit
        self.rate = rate
    }
    
    // MARK: - Computed Properties
    
    public var computedServiceName: String {
        return serviceName
    }
    
    public var computedRate: Double {
        return rate
    }
    
    public var computedUnit: String {
        return unit
    }
}

