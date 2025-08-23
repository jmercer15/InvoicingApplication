//
//  ServiceEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class ServiceEntity {
    public var id: UUID
    var name: String = ""
    var rate: Double = 0.0
    var descriptionText: String?
    var serviceID: Int32? = 0
    var status: String?
    var unit: String?
    var clientServices: [ClientServiceEntity]?
    var ndisItem: NDISItemEntity?
    public init(id: UUID, name: String, rate: Double) {
        self.id = id
        self.name = name
        self.rate = rate
    }
}
