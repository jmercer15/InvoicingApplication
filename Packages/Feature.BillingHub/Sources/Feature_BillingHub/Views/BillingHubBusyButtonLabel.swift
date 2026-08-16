import SwiftUI

/// Shared busy/idle label chrome for Billing Hub panel primary and secondary actions.
enum BillingHubBusyButtonLabel {
    /// Spinner alone while busy; idle shows a full-width symbol label.
    @ViewBuilder
    static func progressOrLabel(
        isBusy: Bool,
        title: String,
        systemImage: String
    ) -> some View {
        if isBusy {
            ProgressView()
                .controlSize(.small)
        } else {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }

    /// Spinner alone while busy; idle shows plain title text (toolbar / secondary bordered actions).
    @ViewBuilder
    static func progressOrText(
        isBusy: Bool,
        title: String
    ) -> some View {
        if isBusy {
            ProgressView()
                .controlSize(.small)
        } else {
            Text(title)
        }
    }

    /// Busy state keeps a titled label with a spinner icon; idle is a full-width symbol label.
    @ViewBuilder
    static func titledProgress(
        isBusy: Bool,
        busyTitle: String,
        idleTitle: String,
        systemImage: String
    ) -> some View {
        if isBusy {
            Label {
                Text(busyTitle)
            } icon: {
                ProgressView()
                    .controlSize(.small)
            }
        } else {
            Label(idleTitle, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
    }
}
