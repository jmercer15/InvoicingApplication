@testable import Data
import Core
import EventKit
import Foundation
import Testing
import PersistenceModels
@MainActor
@Suite struct EventKitSessionWriterTests {
    @Test func MapSessionToEventCopiesCoreFields() throws {
        let manager = RecurrenceRuleManager()
        let writer = EventKitSessionWriter(
            recurrenceRuleManager: manager,
            parsedLocation: { _ in
                EventKitLocationParser.ParsedLocation(
                    preferredLocation: nil,
                    fullAddressText: "",
                    unitNumber: "",
                    streetNumber: "",
                    streetName: "",
                    suburb: "",
                    city: "",
                    state: "",
                    postcode: "",
                    country: "",
                    poBox: "",
                    latitude: 0,
                    longitude: 0
                )
            },
            encodeSyncTag: { _ in nil },
            serializeAlarms: { _ in nil },
            normalizeLocationText: { $0 },
            firstNonEmptyString: { a, b, c in [a, b, c].compactMap { $0 }.first },
            applyParsedAddressToSession: { _, _ in },
            resolvedCoordinate: { _ in nil }
        )

        let store = EKEventStore()
        let event = EKEvent(eventStore: store)

        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(3600)
        let snapshot = SessionSnapshot(
            id: UUID(),
            title: "Session title",
            startTime: start,
            endTime: end,
            isAllDay: false,
            location: "Here",
            notes: "Note body",
            status: .scheduled,
            isTravel: false,
            groupID: nil,
            groupedPosition: 0,
            sessionLatitude: -33.8688,
            sessionLongitude: 151.2093,
            travelDistanceKM: nil,
            travelTimeMinutes: nil,
            travelTollsAmount: nil,
            recurrenceRuleData: nil,
            clientId: nil,
            clientServiceId: nil,
            addressId: nil,
            ndisItemNumber: nil,
            claimType: nil,
            attendeesCount: 0,
            travelCharges: []
        )

        writer.mapSessionToEvent(snapshot, event: event, preserveExistingMetadata: false)

        #expect(event.title == snapshot.title)
        #expect(event.startDate == start)
        #expect(event.endDate == end)
        #expect(event.isAllDay == snapshot.isAllDay)
        #expect(event.location == snapshot.location)
        #expect(event.notes == snapshot.notes)
    }
}
