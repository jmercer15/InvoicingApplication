import Foundation
import XCTest
@testable import Core

final class InvoiceCreationDefaultsTests: XCTestCase {
    func testLoadsSharedPreferenceKeysAndClampsInvalidValues() throws {
        let suiteName = "InvoiceCreationDefaultsTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        preferences.set(-5, forKey: InvoicePreferenceKey.paymentTermsDays)
        preferences.set(250.0, forKey: InvoicePreferenceKey.taxRate)
        preferences.set(false, forKey: InvoicePreferenceKey.showsTaxSummary)
        preferences.set(false, forKey: InvoicePreferenceKey.autoGeneratesInvoiceNumbers)
        preferences.set("Thanks", forKey: InvoicePreferenceKey.notes)
        preferences.set("Due on receipt", forKey: InvoicePreferenceKey.paymentTermsText)

        let defaults = InvoiceCreationDefaults.load(from: preferences)

        XCTAssertEqual(defaults.paymentTermsDays, 0)
        XCTAssertEqual(defaults.taxRate, 100)
        XCTAssertFalse(defaults.showsTaxSummary)
        XCTAssertFalse(defaults.editorConfiguration.showsTaxSummary)
        XCTAssertFalse(defaults.autoGeneratesInvoiceNumbers)
        XCTAssertEqual(defaults.notes, "Thanks")
        XCTAssertEqual(defaults.paymentTermsText, "Due on receipt")
    }

    func testMissingPreferencesUseProductDefaults() throws {
        let suiteName = "InvoiceCreationDefaultsTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { preferences.removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(
            InvoiceCreationDefaults.load(from: preferences),
            InvoiceCreationDefaults.standard
        )
    }
}
