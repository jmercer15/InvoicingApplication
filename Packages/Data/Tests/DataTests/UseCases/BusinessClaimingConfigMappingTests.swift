import XCTest
import Core
@testable import Data

final class BusinessClaimingConfigMappingTests: XCTestCase {
    func testBusinessMapperMapsClaimingFieldsToDomain() {
        let entity = BusinessEntity(id: UUID(), abn: "53004085618")
        entity.name = "Claiming Business"
        entity.ndiaOrganisationID = "123456"
        entity.isRegisteredProvider = true
        entity.defaultGstCode = "P1"

        let mapper = BusinessMapper()
        let domain = mapper.mapToDomain(entity)

        XCTAssertEqual(domain.ndiaOrganisationID, "123456")
        XCTAssertTrue(domain.isRegisteredProvider)
        XCTAssertEqual(domain.defaultGstCode, "P1")
    }

    func testBusinessMapperMapsClaimingFieldsToEntity() {
        let domain = Business(
            id: UUID(),
            name: "Mapped Business",
            abn: "53004085619",
            ndiaOrganisationID: "987654",
            isRegisteredProvider: true,
            defaultGstCode: "P5"
        )

        let mapper = BusinessMapper()
        let entity = mapper.mapToEntity(domain)

        XCTAssertEqual(entity.ndiaOrganisationID, "987654")
        XCTAssertTrue(entity.isRegisteredProvider)
        XCTAssertEqual(entity.defaultGstCode, "P5")
    }
}
