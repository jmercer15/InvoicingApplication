import SwiftUI
import AppIntents

/// Surfaces Shortcuts discovery affordances for workspace navigation intents.
struct WorkspaceShortcutsDiscoveryView: View {
    #if os(iOS)
    @State private var showSiriTip = true
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if os(iOS)
            SiriTipView(intent: OpenWorkspaceTabIntent(tab: .relationships), isVisible: $showSiriTip)
            ShortcutsLink {
                Label("Open Invoicing Shortcuts", systemImage: "square.grid.2x2")
            }
            .help("Create or run Shortcuts for opening tabs and clients.")
            #else
            Text("Use the Shortcuts app to automate opening workspace tabs and clients.")
                .foregroundStyle(.secondary)
            #endif
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Shortcuts and Siri tips")
    }
}
