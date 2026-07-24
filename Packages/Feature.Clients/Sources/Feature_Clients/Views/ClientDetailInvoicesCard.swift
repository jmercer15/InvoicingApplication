import SwiftUI
import Core
import Data
import SharedUI

struct ClientDetailInvoicesCard: View {
    @Bindable var viewModel: ClientDetailViewModel
    let sortedInvoices: [Invoice]
    @Binding var invoicesSortOrder: InvoicesSortOrder
    let onOpenInvoice: (UUID) -> Void

    var body: some View {
        GroupBox {
            VStack(spacing: DetailSectionTokens.sectionListSpacing) {
                DetailListBody(
                    isEmpty: viewModel.relatedInvoices.isEmpty,
                    emptyMessage: "No invoices found"
                ) {
                    ForEach(sortedInvoices) { invoice in
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
