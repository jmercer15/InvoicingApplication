import Foundation
import Testing
import Core

@Suite struct TravelChargeDuplicatePolicyTests {
    @Test func EmptyExistingChargesReturnsFalse() {
        let sessionId = UUID()
        let clientId = UUID()
        #expect(!(TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "labour",
                direction: .before,
                existing: []
            )))
    }

    @Test func DetectsDuplicateMatchingSessionClientTypeDirection() {
        let sessionId = UUID()
        let clientId = UUID()
        let existing = TravelChargeSnapshot(
            id: UUID(),
            travelType: .labour,
            travelDirection: .before,
            sessionId: sessionId,
            clientId: clientId
        )
        #expect(TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "LABOUR",
                direction: .before,
                existing: [existing]
            ))
    }

    @Test func DifferentSessionIsNotDuplicate() {
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
        #expect(!(TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "labour",
                direction: .before,
                existing: [existing]
            )))
    }

    @Test func DifferentDirectionIsNotDuplicate() {
        let sessionId = UUID()
        let clientId = UUID()
        let existing = TravelChargeSnapshot(
            id: UUID(),
            travelType: .labour,
            travelDirection: .before,
            sessionId: sessionId,
            clientId: clientId
        )
        #expect(!(TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "labour",
                direction: .after,
                existing: [existing]
            )))
    }

    @Test func DifferentChargeTypeIsNotDuplicate() {
        let sessionId = UUID()
        let clientId = UUID()
        let existing = TravelChargeSnapshot(
            id: UUID(),
            travelType: .labour,
            travelDirection: .before,
            sessionId: sessionId,
            clientId: clientId
        )
        #expect(!(TravelChargeDuplicatePolicy.hasExistingCharge(
                sessionId: sessionId,
                clientId: clientId,
                chargeType: "non-labour",
                direction: .before,
                existing: [existing]
            )))
    }
}
