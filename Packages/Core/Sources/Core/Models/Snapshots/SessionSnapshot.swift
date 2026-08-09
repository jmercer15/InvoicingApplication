//
//  SessionSnapshot.swift
//  Core
//
//  Sendable value mirrors of SwiftData `@Model` types for cross-actor transfer.
//

import Foundation

// MARK: - SessionSnapshot

public struct SessionSnapshot: Sendable, Equatable, Hashable {
    public let id: UUID
    public let title: String
    public let startTime: Date?
    public let endTime: Date?
    public let isAllDay: Bool
    public let location: String?
    public let notes: String?
    public let attendeesCount: Int32
    public let derivedFromEKEventID: String?
    public let googleColorId: String?
    public let isTravel: Bool
    public let effectiveStatus: SessionStatus
    public let statusToken: String
    public let groupID: UUID?
    public let groupedPosition: Int32
    public let sessionLatitude: Double
    public let sessionLongitude: Double
    public let travelDistanceKM: Double?
    public let travelTimeMinutes: Double?
    public let travelTollsAmount: Double?
    public let assignedServiceName: String?
    public let assignedRate: Decimal?
    public let clientId: UUID?
    public let clientServiceId: UUID?
    public let addressId: UUID?
    public let ndisItemNumber: String?
    public let claimType: String?
    public let invoiceId: UUID?
    public let address: AddressSnapshot?
    public let travelCharges: [TravelChargeSnapshot]
    public let calendarIdentifier: String?
    public let ekCreationDate: Date?
    public let ekEventAvailabilityRaw: Int16
    public let ekEventStatusRaw: Int16
    public let ekRecurrenceRuleDescription: String?
    public let eventIdentifier: String
    public let eventExternalIdentifier: String?
    public let hasEKAlarms: Bool
    public let alarmsData: Data?
    public let isDetached: Bool
    public let lastModifiedDate: Date?
    public let lastSyncTag: String?
    public let eventKitAliasSetData: Data?
    public let eventKitSyncToken: String?
    public let lastObservedRemoteModifiedDate: Date?
    public let isEventKitLinkStale: Bool
    public let eventKitConsecutiveWindowMisses: Int32
    public let organizerName: String?
    public let organizerURL: String?
    public let occurrenceDate: Date?
    public let recurrenceRuleData: Data?
    public let calendarSourceIdentifier: String?
    public let timeZone: String?
    public let url: String?

    /// Backwards-compatible alias for callers that expect `status` to be non-optional.
    public var status: SessionStatus { effectiveStatus }

    public init(
        id: UUID,
        title: String,
        startTime: Date?,
        endTime: Date?,
        isAllDay: Bool,
        location: String?,
        notes: String?,
        status: SessionStatus,
        isTravel: Bool,
        groupID: UUID?,
        groupedPosition: Int32,
        sessionLatitude: Double,
        sessionLongitude: Double,
        travelDistanceKM: Double?,
        travelTimeMinutes: Double?,
        travelTollsAmount: Double?,
        recurrenceRuleData: Data?,
        clientId: UUID?,
        clientServiceId: UUID?,
        addressId: UUID?,
        ndisItemNumber: String?,
        claimType: String?,
        attendeesCount: Int32,
        travelCharges: [TravelChargeSnapshot]
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.effectiveStatus = status
        self.statusToken = status.rawValue
        self.isTravel = isTravel
        self.groupID = groupID
        self.groupedPosition = groupedPosition
        self.sessionLatitude = sessionLatitude
        self.sessionLongitude = sessionLongitude
        self.travelDistanceKM = travelDistanceKM
        self.travelTimeMinutes = travelTimeMinutes
        self.travelTollsAmount = travelTollsAmount
        self.recurrenceRuleData = recurrenceRuleData
        self.clientId = clientId
        self.clientServiceId = clientServiceId
        self.addressId = addressId
        self.ndisItemNumber = ndisItemNumber
        self.claimType = claimType
        self.attendeesCount = attendeesCount
        self.travelCharges = travelCharges

        self.derivedFromEKEventID = nil
        self.googleColorId = nil
        self.assignedServiceName = nil
        self.assignedRate = nil
        self.invoiceId = nil
        self.address = nil
        self.calendarIdentifier = nil
        self.ekCreationDate = nil
        self.ekEventAvailabilityRaw = 0
        self.ekEventStatusRaw = 0
        self.ekRecurrenceRuleDescription = nil
        self.eventIdentifier = ""
        self.eventExternalIdentifier = nil
        self.hasEKAlarms = false
        self.alarmsData = nil
        self.isDetached = false
        self.lastModifiedDate = nil
        self.lastSyncTag = nil
        self.eventKitAliasSetData = nil
        self.eventKitSyncToken = nil
        self.lastObservedRemoteModifiedDate = nil
        self.isEventKitLinkStale = false
        self.eventKitConsecutiveWindowMisses = 0
        self.organizerName = nil
        self.organizerURL = nil
        self.occurrenceDate = nil
        self.calendarSourceIdentifier = nil
        self.timeZone = nil
        self.url = nil
    }

}

