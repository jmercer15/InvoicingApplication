import SwiftUI
import SwiftData
import Data
import SharedUI
import Feature_BillingHub

struct ActivityPlaceholderView: View {
    let billingHubViewModel: BillingHubViewModel
    let openInvoice: (UUID) -> Void
    let openSession: (UUID) -> Void
    @Environment(\.cloudKitSyncMonitor) private var cloudKitSyncMonitor

    var body: some View {
        VStack(spacing: 0) {
            if let cloudKitSyncMonitor {
                CloudKitSyncSidebarIndicator(monitor: cloudKitSyncMonitor)
                    .padding(.horizontal)
                    .padding(.top, StyleGuide.Dimensions.paddingMedium)
            }

            // `\.modelContext` is supplied by the activity scene root; nested children inherit it.
            BillingHubView(
                viewModel: billingHubViewModel,
                openInvoice: openInvoice,
                openSession: openSession
            )
        }
        .frame(
            minWidth: StyleGuide.Dimensions.workspaceActivityMinWidth,
            minHeight: StyleGuide.Dimensions.workspaceActivityMinHeight
        )
    }
}

struct ActivityPlaceholderLoadingView: View {
    var body: some View {
        VStack(spacing: StyleGuide.Dimensions.paddingMediumLarge) {
            ProgressView()
            Text("Loading…")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
        }
        .standardCardStyle()
        .accessibilityLabel("Loading Activity Monitor")
        .frame(
            minWidth: StyleGuide.Dimensions.workspaceActivityLoadingMinWidth,
            minHeight: StyleGuide.Dimensions.workspaceActivityLoadingMinHeight
        )
    }
}
