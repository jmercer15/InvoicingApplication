import XCTest
import Core
@testable import Data

final class InvoiceItemGSTCodeMappingTests: XCTestCase {
    func testInvoiceItemMapperMapsGSTCodeToEntity() {
        let domain = InvoiceItem(
            id: UUID(),
            invoiceId: UUID(),
            itemDescription: "Support Item",
            quantity: 1.5,
            rate: 120.0,
            serviceDate: Date(),
            gstCode: "P1"
        )

        let mapper = InvoiceItemMapper()
        let entity = mapper.mapToEntity(domain)

        XCTAssertEqual(entity.gstCode, "P1")
    }

    func testInvoiceItemMapperMapsGSTCodeToDomain() {
        let entity = InvoiceItemEntity(id: UUID(), itemDescription: "Support Item")
        entity.gstCode = "P5"
        entity.quantity = 2.0
        entity.rate = 90.0

        let mapper = InvoiceItemMapper()
        let domain = mapper.mapToDomain(entity)

        XCTAssertEqual(domain.gstCode, "P5")
    }

    func testInvoiceItemMapperUpdateEntityCanClearGSTCode() {
        var entity = InvoiceItemEntity(id: UUID(), itemDescription: "Support Item")
        entity.gstCode = "P2"

        let updated = InvoiceItem(
            id: entity.id,
            invoiceId: UUID(),
            itemDescription: "Support Item",
            quantity: 1.0,
            rate: 100.0,
            serviceDate: Date(),
            gstCode: nil
        )

        let mapper = InvoiceItemMapper()
        mapper.updateEntity(&entity, from: updated)

        XCTAssertNil(entity.gstCode)
    }
}
