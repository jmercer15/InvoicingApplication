import SwiftUI
import Core
import PersistenceModels
import SharedUI

struct RelationshipDetailInvoicesCard: View {
    let invoices: [Invoice]
    let isEmpty: Bool
    @Binding var invoicesSortOrder: InvoicesSortOrder
    let onOpenInvoice: (UUID) -> Void

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.sectionListSpacing) {
                DetailListBody(
                    isEmpty: isEmpty,
                    emptyMessage: "No invoices found"
                ) {
                    ForEach(invoices, id: \.id) { invoice in
                        Button {
                            onOpenInvoice(invoice.id)
                        } label: {
                            CompactInvoiceRowView(invoice: invoice)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .pointerStyle(.link)
                        .accessibilityLabel("Open invoice \(invoice.invoiceNumber)")
                    }
                }
            }
        } label: {
            DetailSectionHeader(icon: "doc.text", title: "Invoices") {
                DetailSectionSortPicker(selection: $invoicesSortOrder)
            }
        }
        .groupBoxStyle(EnhancedGroupBoxStyle())
    }
}
