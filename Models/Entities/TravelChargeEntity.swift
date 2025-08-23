//
//  TravelChargeEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class TravelChargeEntity: EventRepresentable {
    // Existing properties
    public var id: UUID
    var mmmZoneName: String?
    var travelDistance: Double?
    var travelDuration: Double?
    var vehicleType: String?
    var parkingCost: Double?
    var tollCost: Double?
    var participantCount: Int16?
    var splitCosts: Bool?
    var chargeType: String?
    var travelDirection: String?
    var linkedSession: SessionEntity?
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.travelCharges) var client: ClientEntity?
    @Relationship(deleteRule: .nullify, inverse: \ClientServiceEntity.travelCharges) var service: ClientServiceEntity?
    var auditLogs: [TravelChargeAuditLog]?
    // EventRepresentable protocol properties
    public var calendarIdentifier: String?
    public var ekCreationDate: Date?
    public var ekEventAvailabilityRaw: Int16 = 0
    public var ekEventStatusRaw: Int16 = 0
    public var ekRecurrenceRuleDescription: String?
    public var endTime: Date?
    public var eventIdentifier: String = ""
    public var hasEKAlarms: Bool = false
    public var alarmsData: Data?
    public var isAllDay: Bool = false
    public var isDetached: Bool = false
    public var lastModifiedDate: Date?
    public var lastSyncTag: String?
    public var location: String?
    public var notes: String?
    public var organizerName: String?
    public var organizerURL: String?
    public var occurrenceDate: Date?
    public var recurrenceRuleData: Data?
    public var calendarSourceIdentifier: String?
    public var startTime: Date?
    public var timeZone: String?
    public var title: String = ""
    public var url: String?
    public init(id: UUID) {
        self.id = id
    }
}
