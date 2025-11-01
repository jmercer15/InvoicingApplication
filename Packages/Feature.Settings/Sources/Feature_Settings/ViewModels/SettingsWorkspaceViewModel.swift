import SwiftUI

@MainActor
public final class SettingsWorkspaceViewModel: ObservableObject {
    @Published var selectedSection: SettingsView.SettingsSection? = nil
    @Published var displayedSection: SettingsView.SettingsSection? = nil
    @Published var isTransitioning: Bool = false

    public init() {}
}
