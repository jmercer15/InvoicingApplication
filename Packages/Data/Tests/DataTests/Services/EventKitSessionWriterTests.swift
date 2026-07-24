@testable import Data
import Core
import EventKit
import XCTest

@MainActor
final class EventKitSessionWriterTests: XCTestCase {
    func testMapSessionToEventCopiesCoreFields() throws {
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
        guard let calendar = store.defaultCalendarForNewEvents ?? store.calendars(for: .event).first else {
            throw XCTSkip("No EventKit calendars available in this host environment (cannot validate EKEvent mapping)")
        }

        let event = EKEvent(eventStore: store)
        event.calendar = calendar

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
            sessionLatitude: 0,
            sessionLongitude: 0,
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

        XCTAssertEqual(event.title, snapshot.title)
        XCTAssertEqual(event.startDate, start)
        XCTAssertEqual(event.endDate, end)
        XCTAssertEqual(event.isAllDay, snapshot.isAllDay)
        XCTAssertEqual(event.location, snapshot.location)
        XCTAssertEqual(event.notes, snapshot.notes)
    }
}
