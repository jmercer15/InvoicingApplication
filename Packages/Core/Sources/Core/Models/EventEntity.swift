//
//  EventEntity.swift
//  InvoicingApplication
//
//  Created by Jesse Mercer on 21/7/2025.
//
//

import Foundation


public protocol EventRepresentable {
    var id: UUID { get }
    var calendarIdentifier: String? { get set }
    var ekCreationDate: Date? { get set }
    var ekEventAvailabilityRaw: Int16 { get set }
    var ekEventStatusRaw: Int16 { get set }
    var ekRecurrenceRuleDescription: String? { get set }
    var endTime: Date? { get set }
    var eventIdentifier: String { get set }
    var hasEKAlarms: Bool { get set }
    var alarmsData: Data? { get set }
    var isAllDay: Bool { get set }
    var isDetached: Bool { get set }
    var lastModifiedDate: Date? { get set }
    var lastSyncTag: String? { get set }
    var location: String? { get set }
    var notes: String? { get set }
    var organizerName: String? { get set }
    var organizerURL: String? { get set }
    var occurrenceDate: Date? { get set }
    var recurrenceRuleData: Data? { get set }
    var calendarSourceIdentifier: String? { get set }
    var startTime: Date? { get set }
    var timeZone: String? { get set }
    var title: String { get set }
    var url: String? { get set }
}
