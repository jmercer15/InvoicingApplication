import PersistenceModels
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
    @AppStorage("activityWindowBillingHubTipDismissed") private var tipDismissed = false

    var body: some View {
        VStack(spacing: 0) {
            if let cloudKitSyncMonitor {
                CloudKitSyncSidebarIndicator(monitor: cloudKitSyncMonitor)
                    .padding(.horizontal)
                    .padding(.top, StyleGuide.Dimensions.paddingMedium)
            }

            if !tipDismissed {
                activityBillingHubTip
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

    /// This window mirrors the same live Billing Hub shown in the main workspace tab — clarify
    /// that so a second window doesn't read as a bug or a separate/stale copy of the board.
    private var activityBillingHubTip: some View {
        HStack(spacing: StyleGuide.Dimensions.paddingSmall) {
            Image(systemName: "info.circle")
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .accessibilityHidden(true)

            Text("This is the same Billing Hub as the main window's tab, shown here for a separate view. Changes stay in sync.")
                .font(StyleGuide.Typography.caption)
                .foregroundStyle(StyleGuide.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: StyleGuide.Dimensions.paddingSmall)

            Button {
                tipDismissed = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(StyleGuide.Colors.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss tip")
            .help("Dismiss this tip")
        }
        .padding(.horizontal, StyleGuide.Dimensions.paddingMedium)
        .padding(.vertical, StyleGuide.Dimensions.paddingSmall)
        .background(StyleGuide.Colors.textSecondary.opacity(StyleGuide.Opacity.faint))
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
