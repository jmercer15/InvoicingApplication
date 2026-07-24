import Core
import Foundation
@testable import InvoiceTableLayoutEditor

extension InvoiceModelActor {
    /// Deterministic test convenience. Production creation must capture both preference domains
    /// explicitly through `InvoiceEditorStore` before crossing into SwiftData isolation.
    func createInvoice() throws -> UUID {
        try createInvoice(
            defaults: .standard,
            templateDefaults: InvoiceTemplateDefaults()
        )
    }

    func createInvoice(defaults: InvoiceCreationDefaults) throws -> UUID {
        try createInvoice(
            defaults: defaults,
            templateDefaults: InvoiceTemplateDefaults()
        )
    }
}
