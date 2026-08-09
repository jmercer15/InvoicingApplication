import AppIntents
import Foundation

public struct OpenClientIntent: OpenIntent {
    public static let title: LocalizedStringResource = "Open Client"
    public static let description = IntentDescription("Opens a client in the Relationships tab.")

    @Parameter(title: "Client")
    public var target: ClientEntity

    @Dependency private var modelAccess: AppIntentModelAccess
    @Dependency private var delivery: WorkspaceIntentDeliveryCenter

    public init() {}

    public init(target: ClientEntity) {
        self.target = target
    }

    init(target: ClientEntity, dependencyManager: AppDependencyManager) {
        self.target = target
        self._modelAccess = AppDependency(manager: dependencyManager)
        self._delivery = AppDependency(manager: dependencyManager)
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        try await OpenClientIntentPerforming.perform(
            target: target,
            modelAccess: modelAccess,
            delivery: delivery
        )
        return .result(dialog: IntentDialog(LocalizedStringResource("Opening \(target.displayName).")))
    }
}
