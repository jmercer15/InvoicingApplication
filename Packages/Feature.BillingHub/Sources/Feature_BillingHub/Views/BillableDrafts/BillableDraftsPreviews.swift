import SwiftUI

#Preview("Billable Drafts - Home") {
    BillableDraftsHomePreview()
}

#Preview("Billable Drafts - Detail") {
    BillableDraftDetailPreview()
}

private struct BillableDraftsHomePreview: View {
    var body: some View {
        BillingHubPreviewSupport.DraftsPreviewLoader(minHeight: 640) { payload in
            NavigationStack {
                BillableDraftsHomeView(viewModel: payload.viewModel)
            }
            .modelContainer(payload.container)
            .frame(minWidth: 760, minHeight: 640)
        }
    }
}

private struct BillableDraftDetailPreview: View {
    var body: some View {
        BillingHubPreviewSupport.DraftsPreviewLoader(minHeight: 540) { payload in
            NavigationStack {
                if let draftID = payload.seedData.draftIDs.first {
                    BillableDraftDetailView(
                        draftId: draftID,
                        viewModel: payload.viewModel
                    )
                } else {
                    Text("No preview draft available.")
                        .foregroundStyle(BillingHubTheme.Palette.textSecondary)
                }
            }
            .modelContainer(payload.container)
            .frame(minWidth: 680, minHeight: 540)
        }
    }
}
