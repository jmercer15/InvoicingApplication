import Foundation

enum OpenWorkspaceTabIntentPerforming {
    @MainActor
    static func perform(
        tab: WorkspaceTabAppEnum,
        delivery: WorkspaceIntentDeliveryCenter
    ) {
        delivery.enqueue(.selectTab(tab.appTab))
    }
}
