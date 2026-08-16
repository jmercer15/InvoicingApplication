import SwiftUI
import SharedUI

/// Shows section content when prerequisites are present; otherwise a clear empty state.
struct SettingsServiceGate<Content: View>: View {
    let isAvailable: Bool
    let icon: String
    let title: String
    let message: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        if isAvailable {
            content()
        } else {
            EmptyStateView(icon: icon, title: title, message: message)
        }
    }
}
