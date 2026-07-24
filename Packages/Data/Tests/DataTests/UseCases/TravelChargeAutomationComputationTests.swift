import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class TravelChargeAutomationComputationTests: XCTestCase {
    private var container: ModelContainer!
    private var service: Core.TravelChargeAutomationService!

    override func setUp() async throws {
        try await super.setUp()
        let (inMemoryContainer, context) = try ModelContainerFactory.makeInMemoryContext()
        container = inMemoryContainer
        service = Core.TravelChargeAutomationService(
            modelContext: context,
            businessRules: Core.BusinessRules(),
            userPreferences: Core.UserPreferences(),
            mmmZoneTable: Core.MMMZoneTable(mmmZoneLookup: Core.MMMZoneLookup()),
            recurrenceRuleManager: Core.RecurrenceRuleManager(),
            testingMode: true
        )
    }

    override func tearDown() async throws {
        service = nil
        container = nil
        try await super.tearDown()
    }

    func testCalculatedAmountMappingByChargeType() {
        let breakdown = makeBreakdown(
            labourPerParticipant: 22.0,
            nonLabourPerParticipant: 9.5,
            totalPerParticipant: 31.5
        )

        XCTAssertEqual(service.testCalculatedAmount(for: "labour", breakdown: breakdown), 22.0)
        XCTAssertEqual(service.testCalculatedAmount(for: "non-labour", breakdown: breakdown), 9.5)
        XCTAssertEqual(service.testCalculatedAmount(for: "activity-based", breakdown: breakdown), 31.5)
        XCTAssertEqual(service.testCalculatedAmount(for: "unexpected", breakdown: breakdown), 31.5)
    }

    func testAutomateFromEmptySnapshotsIsNoOp() async {
        await service.automateTravelChargesFromSnapshots(for: [], dateRange: nil)
        let results = service.getTestResults()
        XCTAssertTrue(results.charges.isEmpty)
        XCTAssertTrue(results.reviews.isEmpty)
        XCTAssertTrue(results.detailedReviews.isEmpty)
    }

    func testGenerateTravelChargeNotesIncludesAdjustmentWarnings() {
        let session = Core.Session(id: UUID(), title: "Morning Session")
        let context = Core.TravelChargeAutomationService.SessionAutomationContext(
            session: session.snapshot(),
            client: nil,
            service: nil,
            ndisItem: nil,
            address: nil
        )

        let distanceWarning = Core.ComplianceViolation(
            rule: "Distance Adjustment",
            currentValue: "42.0",
            limit: "20.0",
            description: "Distance exceeded policy cap and was adjusted.",
            severity: .warning
        )
        let travelTimeWarning = Core.ComplianceViolation(
            rule: "Travel Time Adjustment",
            currentValue: "95",
            limit: "30",
            description: "Travel time exceeded MMM cap and was adjusted.",
            severity: .warning
        )

        let notes = service.testGenerateTravelChargeNotes(
            session: context,
            direction: .before,
            distance: 20.0,
            originalDistance: 42.0,
            distanceWarnings: [distanceWarning],
            travelTime: 30.0,
            originalTravelTime: 95.0,
            travelTimeWarnings: [travelTimeWarning],
            mmmZone: Core.MMMZone(name: "MMM 1", maxTime: 30),
            vehicleType: "Car",
            parking: nil,
            tolls: nil,
            participantCount: 2,
            chargeType: "activity-based",
            splitCosts: true,
            pricingBreakdown: makeBreakdown(
                labourPerParticipant: 15.0,
                nonLabourPerParticipant: 4.0,
                totalPerParticipant: 19.0
            )
        )

        XCTAssertTrue(notes.contains("adjusted from 42.0 km"))
        XCTAssertTrue(notes.contains("adjusted from 95 min"))
        XCTAssertTrue(notes.contains("Distance exceeded policy cap and was adjusted."))
        XCTAssertTrue(notes.contains("Travel time exceeded MMM cap and was adjusted."))
        XCTAssertTrue(notes.contains("Total per participant"))
    }

    func testOverrideNoteSuffixIncludesTypeAndReason() {
        let explicit = service.testOverrideNotesSuffix(
            overrideType: "Distance Override",
            overrideReason: "Approved by coordinator"
        )
        XCTAssertTrue(explicit.contains("[Override: Distance Override - Approved by coordinator]"))

        let defaulted = service.testOverrideNotesSuffix(overrideType: nil, overrideReason: nil)
        XCTAssertTrue(defaulted.contains("[Override: Manual - No reason provided]"))
    }

    func testLookupMMMZoneDoesNotUsePostcodeOnlyFallback() {
        let client = Core.Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "Fallback Check",
            status: .active
        )
        let addr = Core.Address()
        addr.postcode = "2000"
        client.address = addr

        let session = Core.Session(id: UUID(), title: "Postcode Only Session")
        let context = Core.TravelChargeAutomationService.SessionAutomationContext(
            session: session.snapshot(),
            client: client.snapshot(),
            service: nil,
            ndisItem: nil,
            address: nil
        )

        XCTAssertNil(
            service.testLookupMMMZone(for: context),
            "Travel charge automation should not derive MMM from postcode-only data."
        )
    }

    func testLookupMMMZoneUsesStoredClientCoordinates() throws {
        let client = Core.Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "Coordinate Check",
            status: .active
        )
        let addr = Core.Address()
        addr.postcode = "7000"
        addr.latitude = -42.8821
        addr.longitude = 147.3272
        client.address = addr

        let session = Core.Session(id: UUID(), title: "Client Coordinate Session")
        session.sessionLatitude = -42.8821
        session.sessionLongitude = 147.3272
        let context = Core.TravelChargeAutomationService.SessionAutomationContext(
            session: session.snapshot(),
            client: client.snapshot(),
            service: nil,
            ndisItem: nil,
            address: nil
        )

        guard let zone = service.testLookupMMMZone(for: context) else {
            throw XCTSkip("MMM polygon data is not bundled in this test host; CoreTests exercise GeoJSON loading.")
        }
        XCTAssertEqual(zone.name, "MMM 2")
    }

    private func makeBreakdown(
        labourPerParticipant: Double,
        nonLabourPerParticipant: Double,
        totalPerParticipant: Double
    ) -> Core.NDISTravelChargeBreakdown {
        Core.NDISTravelChargeBreakdown(
            providerType: .dsw,
            requestedMinutes: 30,
            billableMinutes: 30,
            maxBillableMinutes: 30,
            hourlyRate: 60,
            labourTotal: labourPerParticipant,
            nonLabourTotal: nonLabourPerParticipant,
            grossTotal: totalPerParticipant,
            labourPerParticipant: labourPerParticipant,
            nonLabourPerParticipant: nonLabourPerParticipant,
            totalPerParticipant: totalPerParticipant,
            participantCount: 1
        )
    }
}
