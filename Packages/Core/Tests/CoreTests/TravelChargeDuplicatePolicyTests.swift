import XCTest
import Core

final class TravelChargeDuplicatePolicyTests: XCTestCase {
    func testEmptyExistingChargesReturnsFalse() {
        let sessionId = UUID()
        let clientId = UUID()
        XCTAssertFalse(
            TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "labour",
                direction: .before,
                existing: []
            )
        )
    }

    func testDetectsDuplicateMatchingSessionClientTypeDirection() {
        let sessionId = UUID()
        let clientId = UUID()
        let existing = TravelChargeSnapshot(
            id: UUID(),
            travelType: .labour,
            travelDirection: .before,
            sessionId: sessionId,
            clientId: clientId
        )
        XCTAssertTrue(
            TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "LABOUR",
                direction: .before,
                existing: [existing]
            )
        )
    }

    func testDifferentSessionIsNotDuplicate() {
        let sessionId = UUID()
        let otherSessionId = UUID()
        let clientId = UUID()
        let existing = TravelChargeSnapshot(
            id: UUID(),
            travelType: .labour,
            travelDirection: .before,
            sessionId: otherSessionId,
            clientId: clientId
        )
        XCTAssertFalse(
            TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "labour",
                direction: .before,
                existing: [existing]
            )
        )
    }

    func testDifferentDirectionIsNotDuplicate() {
        let sessionId = UUID()
        let clientId = UUID()
        let existing = TravelChargeSnapshot(
            id: UUID(),
            travelType: .labour,
            travelDirection: .before,
            sessionId: sessionId,
            clientId: clientId
        )
        XCTAssertFalse(
            TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "labour",
                direction: .after,
                existing: [existing]
            )
        )
    }

    func testDifferentChargeTypeIsNotDuplicate() {
        let sessionId = UUID()
        let clientId = UUID()
        let existing = TravelChargeSnapshot(
            id: UUID(),
            travelType: .labour,
            travelDirection: .before,
            sessionId: sessionId,
            clientId: clientId
        )
        XCTAssertFalse(
            TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "non-labour",
                direction: .before,
                existing: [existing]
            )
        )
    }
}
