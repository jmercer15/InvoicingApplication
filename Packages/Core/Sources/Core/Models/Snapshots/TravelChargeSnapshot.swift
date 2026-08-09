//
//  TravelChargeSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - TravelChargeSnapshot

public struct TravelChargeSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let mmmZoneName: String?
    public let chargeAmount: Decimal?
    public let distanceKM: Double?
    public let durationMinutes: Double?
    public let location: String?
    public let notes: String?
    public let title: String
    public let ekEventID: String?
    public let ekCalendarID: String?
    public let ekCreationDate: Date?
    public let ekLastModifiedDate: Date?
    public let latitude: Double
    public let longitude: Double
    public let startTime: Date?
    public let endTime: Date?
    public let effectiveStatus: TravelChargeStatus
    public let travelType: TravelChargeType?
    public let travelDirection: TravelChargeDirection?
    public let vehicleType: VehicleType?
    public let participantCount: Int16?
    public let splitCosts: Bool?
    public let parkingCost: Decimal?
    public let tollCost: Decimal?
    public let sessionId: UUID?
    public let clientId: UUID?
    public let serviceId: UUID?

    public init(
        id: UUID,
        chargeAmount: Decimal? = nil,
        distanceKM: Double? = nil,
        durationMinutes: Double? = nil,
        location: String? = nil,
        effectiveStatus: TravelChargeStatus = .pending,
        travelType: TravelChargeType? = nil,
        travelDirection: TravelChargeDirection? = nil,
        vehicleType: VehicleType? = nil,
        participantCount: Int16? = 1,
        splitCosts: Bool? = false,
        parkingCost: Decimal? = nil,
        tollCost: Decimal? = nil,
        notes: String? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        title: String = "",
        ekEventID: String? = nil,
        ekCalendarID: String? = nil,
        ekCreationDate: Date? = nil,
        ekLastModifiedDate: Date? = nil,
        latitude: Double = 0,
        longitude: Double = 0,
        mmmZoneName: String? = nil,
        sessionId: UUID? = nil,
        clientId: UUID? = nil,
        serviceId: UUID? = nil
    ) {
        self.id = id
        self.chargeAmount = chargeAmount
        self.distanceKM = distanceKM
        self.durationMinutes = durationMinutes
        self.location = location
        self.notes = notes
        self.title = title
        self.ekEventID = ekEventID
        self.ekCalendarID = ekCalendarID
        self.ekCreationDate = ekCreationDate
        self.ekLastModifiedDate = ekLastModifiedDate
        self.latitude = latitude
        self.longitude = longitude
        self.startTime = startTime
        self.endTime = endTime
        self.effectiveStatus = effectiveStatus
        self.travelType = travelType
        self.travelDirection = travelDirection
        self.vehicleType = vehicleType
        self.participantCount = participantCount
        self.splitCosts = splitCosts
        self.parkingCost = parkingCost
        self.tollCost = tollCost
        self.mmmZoneName = mmmZoneName
        self.sessionId = sessionId
        self.clientId = clientId
        self.serviceId = serviceId
    }

}

