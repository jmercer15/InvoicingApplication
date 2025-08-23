//
//  SessionEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation
import SwiftData


@Model public class SessionEntity: EventRepresentable {
    // Existing properties
    public var id: UUID
    var attachmentsData: Data?
    var attendeesCount: Int32 = 0
    var derivedFromEKEventID: String?
    var firstReminderTime: String?
    var googleColorId: String?
    var hasSecondReminder: Bool = false
    var isSystemEvent: Bool = false
    var isTravel: Bool = false
    var secondReminderTime: String?
    var status: String?
    var useRichText: Bool = false
    var sessionLatitude: Double = 0.0
    var sessionLongitude: Double = 0.0
    @Relationship(deleteRule: .nullify) var client: ClientEntity?
    var clientService: ClientServiceEntity?
    @Relationship(deleteRule: .nullify) var invoice: InvoiceEntity?

    var address: AddressEntity?
    @Relationship(deleteRule: .nullify) var invoiceItems: [InvoiceItemEntity]?
    var travelCharges: [TravelChargeEntity]?
    var reviewItems: [TravelChargeReviewItem]?
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


