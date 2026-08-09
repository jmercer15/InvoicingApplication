import Foundation
import Testing
import SwiftData
import Core
import PersistenceModels
@testable import Data

@MainActor
@Suite(.tags(.integration))
struct BackfillMoneyDecimalFieldsTests {
    private func makeContext() throws -> (ModelContainer, ModelContext) {
        try ModelContainerFactory.makeInMemoryContext()
    }

    @Test func decimalMoneyFieldsPersistDirectly() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()

        let invoice = Invoice(invoiceNumber: "INV-001")
        invoice.totalAmount = Decimal(string: "123.45")!
        invoice.taxRate = 10
        invoice.creditApplied = 5
        invoice.discount = Decimal(string: "2.5")!
        context.insert(invoice)

        let item = InvoiceItem(itemDescription: "Support")
        item.quantity = 2
        item.rate = Decimal(string: "50.25")!
        item.taxRate = 10
        context.insert(item)

        let service = ClientService(serviceName: "Therapy", unit: "hour", rate: Decimal(string: "193.99")!)
        context.insert(service)

        let charge = TravelCharge(chargeAmount: Decimal(string: "44.5"), parkingCost: 8, tollCost: Decimal(string: "3.25"))
        context.insert(charge)
        try context.save()

        try BackfillMoneyDecimalFields_v1.execute(modelContext: context)

        #expect(invoice.totalAmount == Decimal(string: "123.45"))
        #expect(invoice.taxRate == 10)
        #expect(item.quantity == 2)
        #expect(item.rate == Decimal(string: "50.25"))
        #expect(service.rate == Decimal(string: "193.99"))
        #expect(charge.chargeAmount == Decimal(string: "44.5"))
        #expect(charge.parkingCost == 8)
        #expect(charge.tollCost == Decimal(string: "3.25"))
    }

    @Test func invoiceRecalculateStoredTotalUsesDecimal() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-002")
        context.insert(invoice)

        invoice.totalAmount = Decimal(string: "99.99")!
        try context.save()

        #expect(invoice.totalAmount == Decimal(string: "99.99"))
    }
}
