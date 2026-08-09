import Core
import Foundation
import Testing

@Suite(.tags(.unit))
struct NDISBillingInputModelsDocumentationTests {
    @Test func billingInputVectorRetainsParticipantAndService() {
        let participant = NDISParticipantInfo(
            ndisNumber: "431234567",
            planManagementType: "Plan Managed",
            location: .init(postcode: "2000", suburb: "Sydney", state: "NSW")
        )
        let service = NDISServiceInfo(
            supportItemNumber: "01_011_0107_1_1",
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            duration: 1,
            quantity: 1,
            date: Date(timeIntervalSince1970: 0)
        )
        let vector = NDISBillingInputVector(
            participant: participant,
            provider: NDISProviderInfo(abn: "12345678901", location: participant.location, foundAlternativeWork: false),
            service: service,
            agreement: NDISAgreementInfo(agreedPrice: 100),
            context: NDISContextInfo()
        )
        #expect(vector.participant.ndisNumber == "431234567")
        #expect(vector.service.supportItemNumber == "01_011_0107_1_1")
    }
}
