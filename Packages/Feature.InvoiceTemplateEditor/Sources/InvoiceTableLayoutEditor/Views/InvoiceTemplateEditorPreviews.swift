#if DEBUG
import SwiftUI

#Preview("Invoice Template Editor") {
    TableLayoutInvoiceEditorView(
        onCreateInvoice: {},
        onOpenInvoices: {},
        isCreatingInvoice: false
    )
    .frame(width: 1180, height: 760)
}
#endif
