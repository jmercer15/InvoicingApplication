import AppIntents
import AppShell

/// App Shortcuts provider — must live in the main app target so Shortcuts /
/// Siri metadata embeds `AppShortcutsProvider` mangled type name in the bundle.
struct InvoicingAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor { .teal }

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenWorkspaceTabIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show \(.applicationName)",
                "Open \(\.$tab) in \(.applicationName)",
                "Show \(\.$tab) in \(.applicationName)",
                "Go to \(\.$tab) in \(.applicationName)",
            ],
            shortTitle: "Open Tab",
            systemImageName: "macwindow"
        )
        AppShortcut(
            intent: OpenClientIntent(),
            phrases: [
                "Open \(\.$target) in \(.applicationName)",
                "Show client \(\.$target) in \(.applicationName)",
            ],
            shortTitle: "Open Client",
            systemImageName: "person.crop.circle"
        )
    }
}
