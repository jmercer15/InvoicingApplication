//
//  BillingHubView+Preview.swift
//  InvoicingApplication
//
//  Preview helpers for BillingHubView.
//

import SwiftUI
import SharedUI

#Preview("Billing Hub - Full View") {
    BillingHubFullPreviewShell()
}

private struct BillingHubFullPreviewShell: View {
    var body: some View {
        BillingHubPreviewSupport.PreviewLoader(minHeight: 680) { payload in
            BillingHubView(viewModel: payload.viewModel)
        }
    }
}
