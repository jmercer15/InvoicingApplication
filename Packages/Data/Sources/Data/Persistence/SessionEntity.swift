//
//  SessionEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class SessionEntity: EventRepresentable, @unchecked Sendable {
    // Existing properties
    public var id: UUID
    public var attendeesCount: Int32 = 0
    public var derivedFromEKEventID: String?
    public var googleColorId: String?
    public var isTravel: Bool = false
    public var status: String?
    // Sessions can be visually grouped in the 'Grouped' subcolumn
    public var groupID: UUID?
    // Position index within the Grouped subcolumn (nil groupID = ungrouped scope)
    public var groupedPosition: Int32 = 0
    public var sessionLatitude: Double = 0.0
    public var sessionLongitude: Double = 0.0
    @Relationship(deleteRule: .nullify, inverse: \ClientEntity.sessions) public var client: ClientEntity?
    @Relationship(deleteRule: .nullify) public var clientService: ClientServiceEntity?
    @Relationship(deleteRule: .nullify) var invoice: InvoiceEntity?

    @Relationship(deleteRule: .nullify) public var address: AddressEntity?
    @Relationship(deleteRule: .nullify, inverse: \InvoiceItemEntity.session) public var invoiceItems: [InvoiceItemEntity] = []
    @Relationship(deleteRule: .nullify, inverse: \TravelChargeEntity.linkedSession) var travelCharges: [TravelChargeEntity] = []
    @Relationship(deleteRule: .cascade) public var reviewItems: [TravelChargeReviewItem] = []
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
