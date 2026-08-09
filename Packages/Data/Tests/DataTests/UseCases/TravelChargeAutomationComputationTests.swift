import Foundation
import CoreLocation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite struct TravelChargeAutomationComputationTests {
    private let container: ModelContainer
    private let service: TravelChargeAutomationService

    init() throws {
        let (container, _) = try ModelContainerFactory.makeInMemoryContext()
        self.container = container
        self.service = TravelChargeAutomationService(
            modelContainer: container,
            businessRules: BusinessRules(),
            userPreferences: UserPreferences(),
            mmmZoneTable: MMMZoneTable(mmmZoneLookup: StubMMMZoneLookup()),
            recurrenceRuleManager: RecurrenceRuleManager(),
            testingMode: true
        )
    }

    @Test func CalculatedAmountMappingByChargeType() async {
        let breakdown = makeBreakdown(
            labourPerParticipant: 22.0,
            nonLabourPerParticipant: 9.5,
            totalPerParticipant: 31.5
        )

        #expect(await service.testCalculatedAmount(for: "labour", breakdown: breakdown) == 22.0)
        #expect(await service.testCalculatedAmount(for: "non-labour", breakdown: breakdown) == 9.5)
        #expect(await service.testCalculatedAmount(for: "activity-based", breakdown: breakdown) == 31.5)
        #expect(await service.testCalculatedAmount(for: "unexpected", breakdown: breakdown) == 31.5)
    }

    @Test func AutomateFromEmptySnapshotsIsNoOp() async {
        await service.automateTravelChargesFromSnapshots(for: [], dateRange: nil)
        let results = await service.getTestResults()
        #expect(results.charges.isEmpty)
        #expect(results.reviews.isEmpty)
        #expect(results.detailedReviews.isEmpty)
    }

    @Test func ModelActorFacadeAcceptsIdentifiersAndReturnsValueResults() async {
        let actor = TravelChargeAutomationActor(modelContainer: container)

        let results = await actor.runAutomation(
            sessionModelIDs: [],
            dateRange: nil,
            testingMode: true,
            mmmZoneLookup: StubMMMZoneLookup(),
            recurrenceRuleManager: RecurrenceRuleManager()
        )

        #expect(results.charges.isEmpty)
        #expect(results.reviews.isEmpty)
        #expect(results.detailedReviews.isEmpty)
    }

    @Test func GenerateTravelChargeNotesIncludesAdjustmentWarnings() async {
        let session = Session(id: UUID(), title: "Morning Session")
        let context = TravelChargeAutomationService.SessionAutomationContext(
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

        let notes = await service.testGenerateTravelChargeNotes(
            session: context,
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

        #expect(notes.contains("adjusted from 42.0 km"))
        #expect(notes.contains("adjusted from 95 min"))
        #expect(notes.contains("Distance exceeded policy cap and was adjusted."))
        #expect(notes.contains("Travel time exceeded MMM cap and was adjusted."))
        #expect(notes.contains("Total per participant"))
    }

    @Test func OverrideNoteSuffixIncludesTypeAndReason() async {
        let explicit = await service.testOverrideNotesSuffix(
            overrideType: "Distance Override",
            overrideReason: "Approved by coordinator"
        )
        #expect(explicit.contains("[Override: Distance Override - Approved by coordinator]"))

        let defaulted = await service.testOverrideNotesSuffix(overrideType: nil, overrideReason: nil)
        #expect(defaulted.contains("[Override: Manual - No reason provided]"))
    }

    @Test func LookupMMMZoneDoesNotUsePostcodeOnlyFallback() async {
        let client = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "Fallback Check",
            status: .active
        )
        let addr = Address()
        addr.postcode = "2000"
        client.address = addr

        let session = Session(id: UUID(), title: "Postcode Only Session")
        let context = TravelChargeAutomationService.SessionAutomationContext(
            session: session.snapshot(),
            client: client.snapshot(),
            service: nil,
            ndisItem: nil,
            address: nil
        )

        #expect(await service.testLookupMMMZone(for: context) == nil, "Travel charge automation should not derive MMM from postcode-only data.")
    }

    @Test func LookupMMMZoneUsesStoredClientCoordinates() async throws {
        let client = Client(
            id: UUID(),
            ndisNumber: "123456789",
            fullName: "Coordinate Check",
            status: .active
        )
        let addr = Address()
        addr.postcode = "7000"
        addr.latitude = -42.8821
        addr.longitude = 147.3272
        client.address = addr

        let session = Session(id: UUID(), title: "Client Coordinate Session")
        session.sessionLatitude = -42.8821
        session.sessionLongitude = 147.3272
        let context = TravelChargeAutomationService.SessionAutomationContext(
            session: session.snapshot(),
            client: client.snapshot(),
            service: nil,
            ndisItem: nil,
            address: nil
        )

        let zone = try #require(await service.testLookupMMMZone(for: context))
        #expect(zone.name == "MMM 2")
    }

    private struct StubMMMZoneLookup: MMMZoneLookupProtocol {
        func mmm(for coord: CLLocationCoordinate2D) -> Int? {
            coord.latitude == -42.8821 && coord.longitude == 147.3272 ? 2 : nil
        }
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
