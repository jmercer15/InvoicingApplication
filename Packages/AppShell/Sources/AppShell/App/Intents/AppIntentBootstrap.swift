import AppIntents
import SwiftData

/// Registers intent dependencies during app launch (including headless Shortcuts invocations).
@MainActor
public enum AppIntentBootstrap {
    public static func registerSharedDependencies() {
        AppDependencyManager.shared.add(dependency: AppIntentModelAccess.shared)
        AppDependencyManager.shared.add(dependency: WorkspaceIntentDeliveryCenter.shared)
    }

    public static func adoptModelContainer(_ container: ModelContainer) async {
        await AppIntentModelAccess.shared.adopt(container: container)
    }
}
