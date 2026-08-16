import Foundation
import Testing
@testable import Core

@Suite struct InvoiceEditorConfigurationTests {
    @Test func DecodesSharedFieldsFromRicherFeatureEnvelope() throws {
        let data = try #require(
            """
            {
              "version": 3,
              "title": "Service Invoice",
              "billParticipantDirectly": false,
              "billToPhone": "07 3000 0000",
              "discountAmount": 12.5,
              "showsTaxSummary": false,
              "paperSize": "a4",
              "template": { "featureOwnedValue": true }
            }
            """.data(using: .utf8)
        )

        let configuration = InvoiceEditorConfiguration(data: data)

        #expect(configuration.version == 3)
        #expect(configuration.title == "Service Invoice")
        #expect(!(configuration.billParticipantDirectly))
        #expect(configuration.billToPhone == "07 3000 0000")
        #expect(configuration.discountAmount == Decimal(string: "12.5"))
        #expect(!(configuration.showsTaxSummary))
    }

    @Test func MissingOrInvalidStateUsesStableDefaults() {
        #expect(InvoiceEditorConfiguration(data: nil) == InvoiceEditorConfiguration())
        #expect(InvoiceEditorConfiguration(data: Data("not-json".utf8)) == InvoiceEditorConfiguration())
    }
}
