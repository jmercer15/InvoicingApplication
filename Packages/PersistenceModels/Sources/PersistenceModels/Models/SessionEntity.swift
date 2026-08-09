//
//  Session.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import Core
import SwiftData


@Model public class Session: EventRepresentable {
    #Index<Session>([\.startTime], [\.endTime], [\.isTravel], [\.location], [\.statusToken])
    
    // Existing properties
    public var id: UUID = UUID()
    public var attendeesCount: Int32 = 0
    public var derivedFromEKEventID: String?
    public var googleColorId: String?
    public var isTravel: Bool = false
    @Attribute(originalName: "status") private var statusData: Data?
    /// Predicate-friendly mirror of `status` (SwiftData cannot predicate over the encoded `statusData`). Backfilled on bootstrap.
    public var statusToken: String = ""

    public var status: SessionStatus? {
        get { PersistenceAttributeCoder.decodeEnum(from: statusData) }
        set {
            statusData = PersistenceAttributeCoder.encodeEnum(newValue)
            statusToken = newValue?.rawValue ?? ""
        }
    }
    // Sessions can be visually grouped in the 'Grouped' subcolumn
    public var groupID: UUID?
    // Position index within the Grouped subcolumn (nil groupID = ungrouped scope)
    public var groupedPosition: Int32 = 0
    public var sessionLatitude: Double = 0.0
    public var sessionLongitude: Double = 0.0
    public var travelDistanceKM: Double?
    public var travelTimeMinutes: Double?
    public var travelTollsAmount: Double?
    /// Cached service display name used by Billing Hub and calendar flows.
    public var assignedServiceName: String?
    /// Cached hourly rate for the assigned service (if known).
    public var assignedRate: Decimal?
    @Relationship(deleteRule: .nullify, inverse: \Client.sessions) public var client: Client?
    @Relationship(deleteRule: .nullify) public var clientService: ClientService?
    @Relationship(deleteRule: .nullify) public var invoice: Invoice?

    @Relationship(deleteRule: .nullify) public var address: Address?
    @Relationship(deleteRule: .nullify, inverse: \InvoiceItem.session) public var invoiceItems: [InvoiceItem]?
    @Relationship(deleteRule: .nullify)
    public var travelCharges: [TravelCharge]?
    @Relationship(deleteRule: .nullify) public var supportLogs: [SupportLog]?
    @Relationship(deleteRule: .nullify) public var reviewItems: [TravelChargeReviewItem]?
    @Relationship(deleteRule: .nullify) public var billableDrafts: [BillableDraft]?
    // EventRepresentable protocol properties
    public var calendarIdentifier: String?
    public var ekCreationDate: Date?
    public var ekEventAvailabilityRaw: Int16 = 0
    public var ekEventStatusRaw: Int16 = 0
    public var ekRecurrenceRuleDescription: String?
    public var endTime: Date?
    public var eventIdentifier: String = ""
    public var eventExternalIdentifier: String?
    public var hasEKAlarms: Bool = false
    public var alarmsData: Data?
    public var isAllDay: Bool = false
    public var isDetached: Bool = false
    public var lastModifiedDate: Date?
    public var lastSyncTag: String?
    /// Encoded EventKit alias set for sync reconciliation (backfill v1).
    public var eventKitAliasSetData: Data?
    /// EventKit sync token (backfill v1).
    public var eventKitSyncToken: String?
    /// Last observed remote modified date (backfill v1).
    public var lastObservedRemoteModifiedDate: Date?
    /// Whether the EventKit link is considered stale (backfill v1/v2).
    public var isEventKitLinkStale: Bool = false
    /// Consecutive window misses for EventKit reconciliation (backfill v2).
    public var eventKitConsecutiveWindowMisses: Int32 = 0
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
    public init(
        id: UUID = UUID(),
        title: String = "",
        startTime: Date? = nil,
        endTime: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        notes: String? = nil,
        status: SessionStatus? = .scheduled,
        isTravel: Bool = false,
        groupID: UUID? = nil,
        groupedPosition: Int32 = 0,
        travelDistanceKM: Double? = nil,
        travelTimeMinutes: Double? = nil,
        recurrenceRuleData: Data? = nil,
        assignedServiceName: String? = nil,
        assignedRate: Decimal? = nil
    ) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.isAllDay = isAllDay
        self.location = location
        self.notes = notes
        self.status = status
        self.isTravel = isTravel
        self.groupID = groupID
        self.groupedPosition = groupedPosition
        self.travelDistanceKM = travelDistanceKM
        self.travelTimeMinutes = travelTimeMinutes
        self.recurrenceRuleData = recurrenceRuleData
        self.assignedServiceName = assignedServiceName
        self.assignedRate = assignedRate
    }

    /// Returns a thread-safe snapshot of this session.
    public func snapshot() -> SessionSnapshot {
        SessionSnapshot(self)
    }

    // MARK: - Computed Properties

    /// Duration in hours
    public var durationHours: Double {
        guard let start = startTime, let end = endTime, end > start else { return 0 }
        return end.timeIntervalSince(start) / 3600.0
    }

    /// Check if session is in the past
    public var isPast: Bool {
        guard let end = endTime else { return false }
        return end < Date()
    }

    /// Check if session is today
    public var isToday: Bool {
        guard let start = startTime else { return false }
        return Calendar.current.isDateInToday(start)
    }

    public var clientId: UUID? { client?.id }
    public var clientServiceId: UUID? { clientService?.id }
    public var addressId: UUID? { address?.id }
}
