//
//  TravelCharge.swift
//  Core
//
//  Created by Jesse Mercer on 21/7/2025.
//

import Foundation
import Core
import SwiftData

@Model public class TravelCharge: EventRepresentable {
    #Index<TravelCharge>([\.startTime], [\.endTime], [\.mmmZoneName], [\.distanceKM], [\.durationMinutes])
    
    public var id: UUID = UUID()
    public var mmmZoneName: String?
    /// CloudKit forbids attribute renames; physical `*Decimal` names stay stable.
    public var chargeAmountDecimal: Decimal?
    public var chargeAmount: Decimal? {
        get { chargeAmountDecimal }
        set { chargeAmountDecimal = newValue }
    }
    public var distanceKM: Double?
    public var durationMinutes: Double?
    public var location: String?
    public var notes: String?
    
    // EventRepresentable fields (standard names used in sync layer)
    public var title: String = ""
    public var ekEventID: String?
    public var ekCalendarID: String?
    public var ekCreationDate: Date?
    public var ekLastModifiedDate: Date?
    public var latitude: Double = 0.0
    public var longitude: Double = 0.0
    public var startTime: Date?
    public var endTime: Date?
    
    // Core attributes using encoded data for persistence safety
    @Attribute(originalName: "status") private var statusData: Data? = PersistenceAttributeCoder.encodeEnum(TravelChargeStatus.pending)
    public var status: TravelChargeStatus? {
        get { PersistenceAttributeCoder.decodeEnum(from: statusData) }
        set { statusData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }

    /// Non-optional status for app code; falls back to .pending when persistence returns nil.
    public var effectiveStatus: TravelChargeStatus {
        get { status ?? .pending }
        set { status = newValue }
    }
    
    @Attribute(originalName: "chargeType") private var chargeTypeData: Data?
    public var chargeType: TravelChargeType? {
        get { PersistenceAttributeCoder.decodeEnum(from: chargeTypeData) }
        set { chargeTypeData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }
    
    public var travelType: TravelChargeType? { // Alias matching repo expectations
        get { chargeType }
        set { chargeType = newValue }
    }
    
    @Attribute(originalName: "travelDirection") private var travelDirectionData: Data?
    public var travelDirection: TravelChargeDirection? {
        get { PersistenceAttributeCoder.decodeEnum(from: travelDirectionData) }
        set { travelDirectionData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }
    
    @Attribute(originalName: "vehicleType") private var vehicleTypeData: Data?
    public var vehicleType: VehicleType? {
        get { PersistenceAttributeCoder.decodeEnum(from: vehicleTypeData) }
        set { vehicleTypeData = PersistenceAttributeCoder.encodeEnum(newValue) }
    }
    
    public var participantCount: Int16? = 1
    public var splitCosts: Bool? = false
    /// CloudKit forbids attribute renames; physical `*Decimal` names stay stable.
    public var parkingCostDecimal: Decimal?
    public var parkingCost: Decimal? {
        get { parkingCostDecimal }
        set { parkingCostDecimal = newValue }
    }
    public var tollCostDecimal: Decimal?
    public var tollCost: Decimal? {
        get { tollCostDecimal }
        set { tollCostDecimal = newValue }
    }
    
    @Relationship(deleteRule: .nullify, inverse: \Client.travelCharges) public var client: Client?
    @Relationship(deleteRule: .nullify, inverse: \Session.travelCharges) public var linkedSession: Session?
    @Relationship(deleteRule: .nullify, inverse: \ClientService.travelCharges) public var service: ClientService?
    @Relationship(deleteRule: .cascade) public var auditLogs: [TravelChargeAuditLog]?
    
    // MARK: - EventRepresentable Protocol Properties
    public var calendarIdentifier: String? { get { ekCalendarID } set { ekCalendarID = newValue } }
    public var eventIdentifier: String { get { ekEventID ?? "" } set { ekEventID = newValue } }
    public var lastModifiedDate: Date? { get { ekLastModifiedDate } set { ekLastModifiedDate = newValue } }
    public var ekEventAvailabilityRaw: Int16 = 0
    public var ekEventStatusRaw: Int16 = 0
    public var ekRecurrenceRuleDescription: String?
    public var hasEKAlarms: Bool = false
    public var alarmsData: Data?
    public var isAllDay: Bool = false
    public var isDetached: Bool = false
    public var lastSyncTag: String?
    public var organizerName: String?
    public var organizerURL: String?
    public var occurrenceDate: Date?
    public var recurrenceRuleData: Data?
    public var calendarSourceIdentifier: String?
    public var timeZone: String?
    public var url: String?
    
    public init(
        id: UUID = UUID(),
        chargeAmount: Decimal? = nil,
        distanceKM: Double? = nil,
        durationMinutes: Double? = nil,
        location: String? = nil,
        status: TravelChargeStatus = .pending,
        chargeType: TravelChargeType? = nil,
        travelDirection: TravelChargeDirection? = nil,
        vehicleType: VehicleType? = nil,
        participantCount: Int16? = 1,
        splitCosts: Bool? = false,
        parkingCost: Decimal? = nil,
        tollCost: Decimal? = nil,
        notes: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil
    ) {
        self.id = id
        self.chargeAmountDecimal = chargeAmount
        self.distanceKM = distanceKM
        self.durationMinutes = durationMinutes
        self.location = location
        self.status = status
        self.chargeType = chargeType
        self.travelDirection = travelDirection
        self.vehicleType = vehicleType
        self.participantCount = participantCount
        self.splitCosts = splitCosts
        self.parkingCostDecimal = parkingCost
        self.tollCostDecimal = tollCost
        self.notes = notes
        self.startTime = startTime
        self.endTime = endTime
    }

    // Alias properties for service compatibility
    public var amount: Decimal? { get { chargeAmount } set { chargeAmount = newValue } }
    public var distance: Double? { get { distanceKM } set { distanceKM = newValue } }
    public var travelTime: Double? { get { durationMinutes } set { durationMinutes = newValue } }

    /// Returns a thread-safe snapshot of the TravelCharge.
    public func snapshot() -> TravelChargeSnapshot {
        TravelChargeSnapshot(self)
    }
}
