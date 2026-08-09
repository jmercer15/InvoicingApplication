#if DEBUG
import Foundation
import SwiftUI

private struct PreviewStartupFailure: LocalizedError {
    var errorDescription: String? {
        "Preview store unavailable."
    }
}

#Preview("Workspace Startup Loading") {
    WorkspaceStartupLoadingView()
        .frame(width: 520, height: 360)
}

#Preview("Settings Startup Loading") {
    SettingsStartupLoadingView()
        .frame(width: 420, height: 280)
}

#Preview("Startup Failure") {
    StartupFailureView(
        error: AppStartupError(underlyingError: PreviewStartupFailure()),
        retry: {},
        startFresh: {}
    )
    .frame(width: 520, height: 360)
}

#Preview("Activity Loading") {
    ActivityPlaceholderLoadingView()
        .padding()
}

#Preview("Workspace Shortcuts Discovery") {
    WorkspaceShortcutsDiscoveryView()
        .frame(width: 360)
        .padding()
}
#endif
