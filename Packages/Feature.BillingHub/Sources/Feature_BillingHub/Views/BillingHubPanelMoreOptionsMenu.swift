import SwiftUI
import SharedUI

/// Groups less-common workflow actions (reopen, reroute, overdue flags, etc.) behind a single
/// disclosure so a panel's primary and secondary actions stay visually dominant. Keeps every
/// action reachable and labeled for VoiceOver — nothing here removes functionality, only visual
/// weight.
struct BillingHubPanelMoreOptionsMenu<MenuItems: View>: View {
    let isDisabled: Bool
    @ViewBuilder let items: () -> MenuItems

    init(isDisabled: Bool = false, @ViewBuilder items: @escaping () -> MenuItems) {
        self.isDisabled = isDisabled
        self.items = items
    }

    var body: some View {
        Menu {
            items()
        } label: {
            Label("More Options", systemImage: "ellipsis.circle")
                .font(StyleGuide.Typography.bodyMedium)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .disabled(isDisabled)
        .accessibilityLabel("More options")
        .accessibilityHint("Shows additional, less common actions for this item.")
    }
}
