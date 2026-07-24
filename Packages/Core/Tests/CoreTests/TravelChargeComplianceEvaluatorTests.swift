import XCTest
@testable import Core

final class TravelChargeComplianceEvaluatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    /// Fixed instant for deterministic overlap assertions.
    private func date(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var c = DateComponents()
        c.year = year
        c.month = month
        c.day = day
        c.hour = hour
        c.minute = minute
        c.timeZone = TimeZone(secondsFromGMT: 0)
        XCTAssertNotNil(calendar.date(from: c))
        return calendar.date(from: c)!
    }

    private func makeSessionSnapshot(
        id: UUID,
        clientId: UUID,
        start: Date?,
        end: Date?,
        isTravel: Bool
    ) -> SessionSnapshot {
        SessionSnapshot(
            id: id,
            title: "",
            startTime: start,
            endTime: end,
            isAllDay: false,
            location: nil,
            notes: nil,
            status: .scheduled,
            isTravel: isTravel,
            groupID: nil,
            groupedPosition: 0,
            sessionLatitude: 0,
            sessionLongitude: 0,
            travelDistanceKM: nil,
            travelTimeMinutes: nil,
            travelTollsAmount: nil,
            recurrenceRuleData: nil,
            clientId: clientId,
            clientServiceId: nil,
            addressId: nil,
            ndisItemNumber: nil,
            claimType: nil,
            attendeesCount: 0,
            travelCharges: []
        )
    }

    private func automationContext(snapshot: SessionSnapshot, clientEntity: Client) -> TravelChargeAutomationService.SessionAutomationContext {
        TravelChargeAutomationService.SessionAutomationContext(
            session: snapshot,
            client: ClientSnapshot(clientEntity),
            service: nil,
            ndisItem: nil,
            address: nil
        )
    }

    func testMaxTravelTimeViolation() {
        var rules = BusinessRules()
        rules.maxTravelTime = 60

        let client = Client(id: UUID(), ndisNumber: "", fullName: "C", status: .active)
        let t0 = date(year: 2026, month: 6, day: 1, hour: 10, minute: 0)
        let t1 = date(year: 2026, month: 6, day: 1, hour: 11, minute: 0)
        let snap = makeSessionSnapshot(id: UUID(), clientId: client.id, start: t0, end: t1, isTravel: false)
        let ctx = automationContext(snapshot: snap, clientEntity: client)

        let result = TravelChargeComplianceEvaluator.evaluate(
            travelTime: 90,
            mmmZone: MMMZone(name: "MMM", maxTime: .infinity),
            businessRules: rules,
            chargeType: "labour",
            distance: 0,
            daySessions: [],
            session: ctx
        )

        XCTAssertFalse(result.isCompliant)
        XCTAssertEqual(result.violations.map(\.rule), ["Max Travel Time"])
    }

    func testAllowedChargeTypesViolationWhenRestricted() {
        var rules = BusinessRules()
        rules.allowedChargeTypes = ["labour"]

        let client = Client(id: UUID(), ndisNumber: "", fullName: "C", status: .active)
        let t0 = date(year: 2026, month: 6, day: 1, hour: 10, minute: 0)
        let t1 = date(year: 2026, month: 6, day: 1, hour: 11, minute: 0)
        let snap = makeSessionSnapshot(id: UUID(), clientId: client.id, start: t0, end: t1, isTravel: false)
        let ctx = automationContext(snapshot: snap, clientEntity: client)

        let result = TravelChargeComplianceEvaluator.evaluate(
            travelTime: 30,
            mmmZone: MMMZone(name: "MMM", maxTime: 100),
            businessRules: rules,
            chargeType: "non-labour",
            distance: 0,
            daySessions: [],
            session: ctx
        )

        XCTAssertFalse(result.isCompliant)
        XCTAssertEqual(result.violations.map(\.rule), ["Allowed Charge Types"])
    }

    func testMMMZoneWarningNearLimit() {
        let client = Client(id: UUID(), ndisNumber: "", fullName: "C", status: .active)
        let t0 = date(year: 2026, month: 6, day: 1, hour: 10, minute: 0)
        let t1 = date(year: 2026, month: 6, day: 1, hour: 11, minute: 0)
        let snap = makeSessionSnapshot(id: UUID(), clientId: client.id, start: t0, end: t1, isTravel: false)
        let ctx = automationContext(snapshot: snap, clientEntity: client)

        let result = TravelChargeComplianceEvaluator.evaluate(
            travelTime: 81,
            mmmZone: MMMZone(name: "MMM", maxTime: 100),
            businessRules: BusinessRules(),
            chargeType: "labour",
            distance: 0,
            daySessions: [],
            session: ctx
        )

        XCTAssertTrue(result.isCompliant)
        XCTAssertTrue(result.violations.isEmpty)
        XCTAssertEqual(result.warnings.map(\.rule), ["Travel Time Warning"])
    }

    func testSameClientAppointmentOverlapProducesViolation() {
        let rules = BusinessRules()

        let client = Client(id: UUID(), ndisNumber: "", fullName: "C", status: .active)
        let travelId = UUID()
        let aptId = UUID()

        let travelStart = date(year: 2026, month: 6, day: 1, hour: 14, minute: 0)
        let travelEnd = date(year: 2026, month: 6, day: 1, hour: 15, minute: 0)
        let aptStart = date(year: 2026, month: 6, day: 1, hour: 14, minute: 30)
        let aptEnd = date(year: 2026, month: 6, day: 1, hour: 15, minute: 30)

        let travelSnap = makeSessionSnapshot(id: travelId, clientId: client.id, start: travelStart, end: travelEnd, isTravel: true)
        let aptSnap = makeSessionSnapshot(id: aptId, clientId: client.id, start: aptStart, end: aptEnd, isTravel: false)

        let travelCtx = automationContext(snapshot: travelSnap, clientEntity: client)
        let aptCtx = automationContext(snapshot: aptSnap, clientEntity: client)

        let daySessions: [TravelChargeAutomationService.SessionInstance] = [
            TravelChargeAutomationService.SessionInstance(session: travelCtx, instanceStart: travelStart, instanceEnd: travelEnd),
            TravelChargeAutomationService.SessionInstance(session: aptCtx, instanceStart: aptStart, instanceEnd: aptEnd),
        ]

        let result = TravelChargeComplianceEvaluator.evaluate(
            travelTime: 20,
            mmmZone: MMMZone(name: "MMM", maxTime: .infinity),
            businessRules: rules,
            chargeType: "labour",
            distance: 0,
            daySessions: daySessions,
            session: travelCtx
        )

        XCTAssertFalse(result.isCompliant)
        XCTAssertTrue(result.violations.contains { $0.rule == "Time Overlap Prevention" })
    }

    func testCompliantBaselineWithNoRestrictionsAndEmptyDay() {
        var rules = BusinessRules()
        rules.maxTravelTime = nil
        rules.allowedChargeTypes = nil

        let client = Client(id: UUID(), ndisNumber: "", fullName: "C", status: .active)
        let t0 = date(year: 2026, month: 6, day: 1, hour: 10, minute: 0)
        let t1 = date(year: 2026, month: 6, day: 1, hour: 11, minute: 0)
        let snap = makeSessionSnapshot(id: UUID(), clientId: client.id, start: t0, end: t1, isTravel: false)
        let ctx = automationContext(snapshot: snap, clientEntity: client)

        let result = TravelChargeComplianceEvaluator.evaluate(
            travelTime: 45,
            mmmZone: MMMZone(name: "MMM", maxTime: .infinity),
            businessRules: rules,
            chargeType: "anything",
            distance: 0,
            daySessions: [],
            session: ctx
        )

        XCTAssertTrue(result.isCompliant)
        XCTAssertTrue(result.violations.isEmpty)
        XCTAssertTrue(result.warnings.isEmpty)
    }
}
