import Observation

@Observable
@MainActor
public final class SettingsWorkspaceViewModel {
    var selectedSection: SettingsView.SettingsSection? = .profile

    public init() {}
}
