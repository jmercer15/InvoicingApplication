import XCTest
import SwiftData
import Core
@testable import Data

@MainActor
final class TravelChargeAutomationComputationTests: XCTestCase {
    private var modelContext: ModelContext!
    private var service: TravelChargeAutomationService!

    override func setUp() async throws {
        try await super.setUp()
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        modelContext = context
        service = TravelChargeAutomationService(
            context: modelContext,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable(),
            testingMode: true
        )
    }

    override func tearDown() async throws {
        service = nil
        modelContext = nil
        try await super.tearDown()
    }

    func testCalculatedAmountMappingByChargeType() {
        let breakdown = makeBreakdown(
            labourPerParticipant: 22.0,
            nonLabourPerParticipant: 9.5,
            totalPerParticipant: 31.5
        )

        XCTAssertEqual(service._testCalculatedAmount(for: "labour", breakdown: breakdown), 22.0)
        XCTAssertEqual(service._testCalculatedAmount(for: "non-labour", breakdown: breakdown), 9.5)
        XCTAssertEqual(service._testCalculatedAmount(for: "activity-based", breakdown: breakdown), 31.5)
        XCTAssertEqual(service._testCalculatedAmount(for: "unexpected", breakdown: breakdown), 31.5)
    }

    func testGenerateTravelChargeNotesIncludesAdjustmentWarnings() {
        let session = SessionEntity(id: UUID())
        session.title = "Morning Session"

        let distanceWarning = ComplianceViolation(
            rule: "Distance Adjustment",
            currentValue: "42.0",
            limit: "20.0",
            description: "Distance exceeded policy cap and was adjusted.",
            severity: .warning
        )
        let travelTimeWarning = ComplianceViolation(
            rule: "Travel Time Adjustment",
            currentValue: "95",
            limit: "30",
            description: "Travel time exceeded MMM cap and was adjusted.",
            severity: .warning
        )

        let notes = service._testGenerateTravelChargeNotes(
            session: session,
            direction: .before,
            distance: 20.0,
            originalDistance: 42.0,
            distanceWarnings: [distanceWarning],
            travelTime: 30.0,
            originalTravelTime: 95.0,
            travelTimeWarnings: [travelTimeWarning],
            mmmZone: MMMZone(name: "MMM 1", maxTime: 30),
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
        let explicit = service._testOverrideNotesSuffix(
            overrideType: "Distance Override",
            overrideReason: "Approved by coordinator"
        )
        XCTAssertTrue(explicit.contains("[Override: Distance Override - Approved by coordinator]"))

        let defaulted = service._testOverrideNotesSuffix(overrideType: nil, overrideReason: nil)
        XCTAssertTrue(defaulted.contains("[Override: Manual - No reason provided]"))
    }

    private func makeBreakdown(
        labourPerParticipant: Double,
        nonLabourPerParticipant: Double,
        totalPerParticipant: Double
    ) -> NDISTravelChargeBreakdown {
        NDISTravelChargeBreakdown(
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
