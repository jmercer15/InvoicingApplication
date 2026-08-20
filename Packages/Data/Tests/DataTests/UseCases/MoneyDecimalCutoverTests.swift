import Foundation
import Core
import PersistenceModels
import SwiftData
import Testing
import CoreTesting
@testable import Data

@MainActor
@Suite(.serialized, .tags(.integration))
struct MoneyDecimalCutoverTests {
    @Test func appSchemaV4RegisteredInMigrationPlanWithoutEqualChecksumStages() {
        let schemaIDs = AppMigrationPlan.schemas.map { $0.versionIdentifier }
        #expect(schemaIDs == [Schema.Version(4, 0, 0)])
        #expect(AppMigrationPlan.stages.isEmpty)
    }

    @Test func invoiceMoneyFieldsRoundTripInMemory() throws {
        let (_, context) = try ModelContainerFactory.makeInMemoryContext()
        let invoice = Invoice(invoiceNumber: "INV-DEC")
        invoice.totalAmount = Decimal(string: "250.50")!
        invoice.taxRate = Decimal(string: "10")!
        invoice.discount = Decimal(string: "5")!
        invoice.creditApplied = Decimal(string: "2.50")!
        context.insert(invoice)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Invoice>()).first
        #expect(fetched?.totalAmount == Decimal(string: "250.50"))
        #expect(fetched?.taxRate == 10)
        #expect(fetched?.discount == 5)
        #expect(fetched?.creditApplied == Decimal(string: "2.50"))
    }

    @Test func exportMachineFormattingUsesDecimalTokens() {
        #expect(ExportMachineFormatting.exportDecimal2(Decimal(string: "123.45")!) == "123.45")
        #expect(ExportMachineFormatting.exportDecimal3(Decimal(string: "2.5")!) == "2.5")
    }
}
