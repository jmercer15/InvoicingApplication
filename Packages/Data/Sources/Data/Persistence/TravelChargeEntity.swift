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
    public var mmmZoneName: String?
    public var travelDistance: Double?
    public var travelDuration: Double?
    public var vehicleType: String?
    public var parkingCost: Double?
    public var tollCost: Double?
    public var participantCount: Int16?
    public var splitCosts: Bool?
    public var chargeType: String?
    public var travelDirection: String?
    @Relationship(deleteRule: .nullify) public var linkedSession: SessionEntity?
    @Relationship(deleteRule: .nullify) public var client: ClientEntity?
    @Relationship(deleteRule: .nullify) public var service: ClientServiceEntity?
    // Note: auditLogs relationship will be added when TravelChargeAuditLogEntity is implemented
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
