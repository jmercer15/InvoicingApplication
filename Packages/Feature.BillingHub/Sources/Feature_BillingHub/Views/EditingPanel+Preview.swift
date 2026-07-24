import SwiftUI

#Preview("Editing Panel - Session") {
    EditingPanelSessionPreview()
}

#Preview("Editing Panel - Invoice") {
    EditingPanelInvoicePreview()
}

private struct EditingPanelSessionPreview: View {
    var body: some View {
        BillingHubPreviewSupport.PreviewLoader(minHeight: 640) { payload in
            Group {
                if let card = payload.projection.sessionsByStatus.values.flatMap({ $0 }).first {
                    EditingPanel(card: card, viewModel: payload.viewModel)
                        .frame(minWidth: 560, minHeight: 640)
                } else {
                    Text("No preview session available.")
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                        .frame(minWidth: 560, minHeight: 640)
                }
            }
        }
    }
}

private struct EditingPanelInvoicePreview: View {
    var body: some View {
        BillingHubPreviewSupport.PreviewLoader(minHeight: 640) { payload in
            Group {
                if let card = payload.projection.invoicesByStatus.values.flatMap({ $0 }).first {
                    EditingPanel(card: card, viewModel: payload.viewModel)
                        .frame(minWidth: 560, minHeight: 640)
                } else {
                    Text("No preview invoice available.")
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                        .frame(minWidth: 560, minHeight: 640)
                }
            }
        }
    }
}
