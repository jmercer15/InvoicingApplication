import Foundation
import Testing
@testable import Core

@Suite struct InvoiceCreationDefaultsTests {
    @Test func LoadsSharedPreferenceKeysAndClampsInvalidValues() throws {
        let suiteName = "InvoiceCreationDefaultsTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        preferences.set(-5, forKey: InvoicePreferenceKey.paymentTermsDays)
        preferences.set(250.0, forKey: InvoicePreferenceKey.taxRate)
        preferences.set(false, forKey: InvoicePreferenceKey.showsTaxSummary)
        preferences.set(false, forKey: InvoicePreferenceKey.autoGeneratesInvoiceNumbers)
        preferences.set("Thanks", forKey: InvoicePreferenceKey.notes)
        preferences.set("Due on receipt", forKey: InvoicePreferenceKey.paymentTermsText)

        let defaults = InvoiceCreationDefaults.load(from: preferences)

        #expect(defaults.paymentTermsDays == 0)
        #expect(defaults.taxRate == 100)
        #expect(!(defaults.showsTaxSummary))
        #expect(!(defaults.editorConfiguration.showsTaxSummary))
        #expect(!(defaults.autoGeneratesInvoiceNumbers))
        #expect(defaults.notes == "Thanks")
        #expect(defaults.paymentTermsText == "Due on receipt")
    }

    @Test func MissingPreferencesUseProductDefaults() throws {
        let suiteName = "InvoiceCreationDefaultsTests.\(UUID().uuidString)"
        let preferences = try #require(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        #expect(InvoiceCreationDefaults.load(from: preferences) == InvoiceCreationDefaults.standard)
    }
}
