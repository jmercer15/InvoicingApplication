import AppIntents
import Core

public struct OpenWorkspaceTabIntent: AppIntent {
    public static let title: LocalizedStringResource = "Open Workspace Tab"
    public static let description = IntentDescription("Opens a workspace tab in Invoicing Application.")
    public static let openAppWhenRun = true

    @Parameter(title: "Tab", default: .relationships)
    public var tab: WorkspaceTabAppEnum

    public init() {}

    public init(tab: WorkspaceTabAppEnum) {
        self.tab = tab
    }

    @Dependency private var delivery: WorkspaceIntentDeliveryCenter

    @MainActor
    public func perform() async throws -> some IntentResult {
        OpenWorkspaceTabIntentPerforming.perform(tab: tab, delivery: delivery)
        return .result(dialog: "Opening \(tab.appTab.title).")
    }
}
